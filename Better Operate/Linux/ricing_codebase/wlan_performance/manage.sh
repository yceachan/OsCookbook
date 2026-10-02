#!/usr/bin/env bash

set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script_path="$project_dir/$(basename -- "${BASH_SOURCE[0]}")"
state_root=/var/lib/ricing-wlan-performance
active_state=$state_root/active
history_dir=$state_root/history

nm_source=$project_dir/src/NetworkManager/10-wifi-performance.conf
nm_target=/etc/NetworkManager/conf.d/10-wifi-performance.conf
driver_source=$project_dir/src/modprobe.d/rtw89-performance.conf
driver_target=/etc/modprobe.d/rtw89-performance.conf

module_parameters=(
    /sys/module/rtw89_core/parameters/disable_ps_mode
    /sys/module/rtw89_pci/parameters/disable_clkreq
    /sys/module/rtw89_pci/parameters/disable_aspm_l1
    /sys/module/rtw89_pci/parameters/disable_aspm_l1ss
)

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_sources() {
    [[ -r $nm_source ]] || die "missing source: $nm_source"
    [[ -r $driver_source ]] || die "missing source: $driver_source"
    grep -Fxq 'wifi.powersave=2' "$nm_source" || die 'NetworkManager source does not disable Wi-Fi power saving'
    grep -Fq 'disable_ps_mode=Y' "$driver_source" || die 'rtw89 source does not disable low-power mode'
}

require_rtw89() {
    local parameter
    for parameter in "${module_parameters[@]}"; do
        [[ -e $parameter ]] || die "required rtw89 parameter is unavailable: $parameter"
    done
}

elevate_if_needed() {
    if (( EUID != 0 )); then
        require_command pkexec
        exec pkexec "$script_path" "$@"
    fi
}

wifi_connections() {
    nmcli -t -f UUID,TYPE connection show |
        while IFS=: read -r uuid type; do
            [[ $type == 802-11-wireless ]] && printf '%s\n' "$uuid"
        done
}

wifi_interfaces() {
    iw dev | awk '$1 == "Interface" { print $2 }'
}

capture_state() {
    [[ ! -e $active_state ]] || return 0

    local staging
    install -d -m 0700 "$state_root"
    staging=$(mktemp -d "$state_root/.active.XXXXXX")
    install -d -m 0700 "$staging/backups" "$staging/absent"

    if [[ -e $nm_target ]]; then
        cp -a -- "$nm_target" "$staging/backups/networkmanager.conf"
    else
        : > "$staging/absent/networkmanager"
    fi

    if [[ -e $driver_target ]]; then
        cp -a -- "$driver_target" "$staging/backups/modprobe.conf"
    else
        : > "$staging/absent/modprobe"
    fi

    local uuid value interface parameter
    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        value=$(nmcli -g 802-11-wireless.powersave connection show "$uuid")
        printf '%s\t%s\n' "$uuid" "$value" >> "$staging/connections.tsv"
    done < <(wifi_connections)

    while IFS= read -r interface; do
        [[ -n $interface ]] || continue
        value=$(iw dev "$interface" get power_save | awk '{ print $NF }')
        printf '%s\t%s\n' "$interface" "$value" >> "$staging/interfaces.tsv"
    done < <(wifi_interfaces)

    for parameter in "${module_parameters[@]}"; do
        value=$(<"$parameter")
        printf '%s\t%s\n' "$parameter" "$value" >> "$staging/modules.tsv"
    done

    {
        printf 'format=1\n'
        printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
    } > "$staging/manifest"

    mv -- "$staging" "$active_state"
}

apply_configuration() {
    require_sources
    require_rtw89
    capture_state

    install -Dm0644 -- "$nm_source" "$nm_target"
    install -Dm0644 -- "$driver_source" "$driver_target"

    local uuid interface parameter
    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        nmcli connection modify "$uuid" 802-11-wireless.powersave 2
    done < <(wifi_connections)

    for parameter in "${module_parameters[@]}"; do
        printf Y > "$parameter"
    done

    while IFS= read -r interface; do
        [[ -n $interface ]] || continue
        iw dev "$interface" set power_save off
    done < <(wifi_interfaces)

    nmcli general reload conf
    printf 'WLAN performance policy applied.\n'
}

restore_file() {
    local key=$1 target=$2 backup=$3
    if [[ -e $active_state/absent/$key ]]; then
        [[ ! -e $target ]] || unlink -- "$target"
    elif [[ -e $active_state/backups/$backup ]]; then
        cp -a -- "$active_state/backups/$backup" "$target"
    else
        die "rollback metadata is incomplete for $target"
    fi
}

rollback_configuration() {
    [[ -r $active_state/manifest ]] || die 'no active rollback snapshot exists'

    restore_file networkmanager "$nm_target" networkmanager.conf
    restore_file modprobe "$driver_target" modprobe.conf

    local uuid value interface parameter
    while IFS=$'\t' read -r uuid value; do
        [[ -n $uuid ]] || continue
        if nmcli connection show "$uuid" >/dev/null 2>&1; then
            nmcli connection modify "$uuid" 802-11-wireless.powersave "$value"
        else
            die "captured Wi-Fi connection no longer exists: $uuid"
        fi
    done < "$active_state/connections.tsv"

    while IFS=$'\t' read -r parameter value; do
        [[ -e $parameter ]] || die "captured module parameter is unavailable: $parameter"
        printf '%s' "$value" > "$parameter"
    done < "$active_state/modules.tsv"

    while IFS=$'\t' read -r interface value; do
        iw dev "$interface" info >/dev/null 2>&1 || die "captured Wi-Fi interface is unavailable: $interface"
        iw dev "$interface" set power_save "$value"
    done < "$active_state/interfaces.tsv"

    nmcli general reload conf
    install -d -m 0700 "$history_dir"
    mv -- "$active_state" "$history_dir/$(date +%Y%m%dT%H%M%S)"
    printf 'WLAN performance policy rolled back to the captured pre-apply state.\n'
}

show_status() {
    local failed=0 value interface parameter uuid

    if cmp -s -- "$nm_source" "$nm_target"; then
        printf 'NetworkManager config: managed\n'
    else
        printf 'NetworkManager config: not applied\n'
        failed=1
    fi

    if cmp -s -- "$driver_source" "$driver_target"; then
        printf 'rtw89 config:         managed\n'
    else
        printf 'rtw89 config:         not applied\n'
        failed=1
    fi

    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        value=$(nmcli -g 802-11-wireless.powersave connection show "$uuid")
        printf 'Wi-Fi profile %s: %s\n' "$uuid" "$value"
        [[ $value == disable ]] || failed=1
    done < <(wifi_connections)

    while IFS= read -r interface; do
        [[ -n $interface ]] || continue
        value=$(iw dev "$interface" get power_save | awk '{ print $NF }')
        printf 'Interface %s power save: %s\n' "$interface" "$value"
        [[ $value == off ]] || failed=1
    done < <(wifi_interfaces)

    for parameter in "${module_parameters[@]}"; do
        if [[ -e $parameter ]]; then
            value=$(<"$parameter")
            printf '%s: %s\n' "${parameter#/sys/module/}" "$value"
            [[ $value == Y ]] || failed=1
        else
            printf '%s: unavailable\n' "${parameter#/sys/module/}"
            failed=1
        fi
    done

    if [[ -r $active_state/manifest ]]; then
        printf 'Rollback snapshot: ready\n'
    else
        printf 'Rollback snapshot: missing\n'
        failed=1
    fi

    return "$failed"
}

usage() {
    printf 'Usage: %s {apply|status|rollback}\n' "${0##*/}"
}

main() {
    local action=${1:-}
    for command_name in awk cmp grep iw nmcli; do
        require_command "$command_name"
    done

    case $action in
        apply)
            elevate_if_needed "$@"
            for command_name in cp install mktemp mv; do
                require_command "$command_name"
            done
            apply_configuration
            ;;
        status)
            require_sources
            show_status
            ;;
        rollback)
            elevate_if_needed "$@"
            for command_name in cp install mv unlink; do
                require_command "$command_name"
            done
            rollback_configuration
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
