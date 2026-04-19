# React：函数式编程与显式 UI 构建

**React** 是由 Meta (Facebook) 开源的用于构建用户界面的 JavaScript 库。它不仅仅是一个库，更是一种深刻影响了整个前端工程化走向的设计范式。

它的核心思想是：**UI 应该像数学函数一样，是状态的纯粹映射。**

## 1. 核心理念：All in JS 与不可变性

**传统分离模式：**
传统的 Web 开发提倡“关注点分离”：HTML 负责结构，CSS 负责样式，JS 负责逻辑。它们存在于不同的文件中。

**React 的 "All in JS" 模式：**
React 认为，在一个组件中，结构和逻辑是高度耦合的。它引入了 **JSX**（JavaScript XML），允许你在 JS 代码中直接编写类似 HTML 的标签。
```jsx
function Counter() {
  const [count, setCount] = useState(0); // 状态
  
  return (
    <div className="card"> {/* 结构与样式类 */}
      <p>You clicked {count} times</p>
      <button onClick={() => setCount(count + 1)}> {/* 逻辑绑定 */}
        Click me
      </button>
    </div>
  );
}
```

**不可变性 (Immutability)：**
React 强调数据不能被直接修改。在上面的例子中，我们不能写 `count = count + 1`，必须调用 `setCount`。这使得 React 可以极其快速地通过判断对象引用地址是否变化来决定是否需要重新渲染。

## 2. 为什么 React 统治了企业级应用？

*   **极强的灵活性：** React 本质上就是 JavaScript。你不需要学习 `v-if` 或 `v-for` 这种特定框架的模板语法，而是直接使用原生的 `if` 和 `map()`。这赋予了它处理极度复杂逻辑的能力。
*   **单向数据流：** 数据永远从父组件流向子组件。如果子组件想修改数据，必须调用父组件传下来的回调函数。这使得在庞大应用中，数据流向非常清晰，极大地降低了 Debug 的难度。
*   **繁荣但分散的生态：** React 官方只提供渲染能力（UI 库）。路由（React Router）、状态管理（Redux, Zustand）、请求库（React Query）全靠社区繁荣。这意味着你可以为大型项目挑选最极致的武器组合。

## 3. 核心机制：Hooks 与 Fiber

*   **Hooks (钩子)：**
    React 16.8 引入的革命性特性。过去，只有繁琐的 Class 组件才能拥有状态；现在，通过 `useState`, `useEffect` 等 Hooks，简单的函数组件不仅能拥有状态，还能将逻辑非常干净地抽取和复用（Custom Hooks）。
*   **Fiber (并发渲染引擎)：**
    如前文所属，React Fiber 将渲染任务切片，允许渲染过程被高优先级事件（如用户输入）打断，防止主线程阻塞。这为 React 带来了“并发模式 (Concurrent Mode)”，是支撑复杂动画和大规模数据渲染的底层基石。

## 4. React 的痛点与争议

*   **陡峭的学习曲线：** 你必须精通 JavaScript 的闭包、高阶函数和上下文 (`this`)。
*   **心智负担重 (闭包陷阱)：** 如果不深刻理解 `useEffect` 的依赖数组，很容易写出死循环或者取到旧状态的 Bug。
*   **需要手动优化性能：** 因为 React 只要状态变了就会默认重渲染整棵子树，开发者经常需要手动使用 `useMemo`, `useCallback`, `React.memo` 来阻断不必要的渲染。

**总结：**
React 是一个下限不低、上限极高的兵器。它迫使你用纯函数和不可变数据的思维来思考 UI，是构建复杂、大型、高交互 Web 应用程序的首选。