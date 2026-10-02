在源码分页处插入
```html
<div class="page-break"></div>
```

在主题css中插入（once）

```css
@media print { .page-break { break-after: page; page-break-after: always; } }
```

