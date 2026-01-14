- BG :对于MB级别的大型的非通用格式文档，如`.pdf`;`.xlsx`;`.docx`等格式：
  - 相较轻量化的普通文本类型文档（md,txt,程序源码等)，没有好用的`cli或mcp工具集`来通过`grep`、`cat`等文本处理工具来提炼上下文，进行RAG(Retrieval-Augmented Generation ，检索生成强化)
  - [重要] 因而，当开发者强调要求、或在其prompt content下，相关领域的知识的索引指向了一个大型的非不同文档时**：Agent应积极地编写或调用知识库索引中记忆的python脚本工具**，来fetch这些大型文档内部，prompt内容相关的content，**如，编写py脚本，调用excel库，通过对某列的筛选功能，从庞杂的寄存器位定义表里筛选出目标外设相关的寄存器分表。**
  - [面向开发者] 开发者应该积极地向Agent prompt编写脚本的策略，指示Agent如何多样化需求地处理多样形式的大型文档。

