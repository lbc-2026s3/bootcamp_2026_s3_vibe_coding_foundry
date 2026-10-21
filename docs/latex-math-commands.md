# LaTeX 公式常用指令

写公式前在导言区加上：

```latex
\usepackage{amsmath,amssymb}
```

`amsmath` 提供 `align`、`cases`、`\text` 等；`amssymb` 提供 `\mathbb`、`\leqslant` 这类符号。

行内公式用 `$...$`，独立成行用 `\[...\]`。需要编号时用 `equation`。

```latex
行内：$a^2 + b^2 = c^2$。

\[
E = mc^2
\]

\begin{equation}
e^{i\pi} + 1 = 0
\end{equation}
```

---

## 上下标、分式、根号

| 效果 | 指令 |
| --- | --- |
| 上标 | `x^{2}`、`e^{-x}` |
| 下标 | `a_{i}`、`x_{i,j}` |
| 上下标一起 | `a_{n}^{2}` |
| 分式 | `\frac{a}{b}` |
| 行内小分式 | `\tfrac{a}{b}` |
| 根号 | `\sqrt{x}`、`\sqrt[n]{x}` |

单独一个字符的上下标可以不加大括号：`x^2`、`a_i`。两个及以上字符必须加大括号，否则只作用在第一个字符上。

---

## 希腊字母

小写直接写名字，大写把首字母大写。没有对应大写指令的字母（如 alpha）用拉丁字母即可。

| 小写 | 指令 | 大写 | 指令 |
| --- | --- | --- | --- |
| α | `\alpha` | Γ | `\Gamma` |
| β | `\beta` | Δ | `\Delta` |
| γ | `\gamma` | Θ | `\Theta` |
| δ | `\delta` | Λ | `\Lambda` |
| ε / ϵ | `\epsilon` / `\varepsilon` | Ξ | `\Xi` |
| θ / ϑ | `\theta` / `\vartheta` | Π | `\Pi` |
| λ | `\lambda` | Σ | `\Sigma` |
| μ | `\mu` | Φ | `\Phi` |
| π / ϖ | `\pi` / `\varpi` | Ψ | `\Psi` |
| ρ / ϱ | `\rho` / `\varrho` | Ω | `\Omega` |
| σ | `\sigma` | | |
| φ / ϕ | `\phi` / `\varphi` | | |
| ω | `\omega` | | |

变体（`\varepsilon`、`\varphi`、`\vartheta`）和标准形是不同符号，同一篇文档里选定一种后保持一致。

---

## 运算与大型算符

| 效果 | 指令 |
| --- | --- |
| ± ∓ × ÷ · | `\pm` `\mp` `\times` `\div` `\cdot` |
| ∑ ∏ ∫ ∮ | `\sum` `\prod` `\int` `\oint` |
| ∂ ∇ ∞ | `\partial` `\nabla` `\infty` |

大型算符的上下限：行内用 `\sum_{i=1}^{n}`，独立公式里上下限会自动放到符号上下方。想在行内也堆到上下方，加 `\displaystyle`：

```latex
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}

\int_{0}^{\infty} e^{-x}\,dx = 1
```

`\,` 是一个窄空格，积分的 `dx` 前面习惯加它。

极限、最大最小：

```latex
\lim_{n \to \infty} a_n
\max_{x \in S} f(x)
\arg\min_{\theta} L(\theta)
```

---

## 关系、箭头、集合

| 效果 | 指令 |
| --- | --- |
| = ≠ ≈ ≡ ∼ ∝ | `=` `\neq` `\approx` `\equiv` `\sim` `\propto` |
| < > ≤ ≥ ≪ ≫ | `<` `>` `\leq` `\geq` `\ll` `\gg` |
| ∈ ∉ ⊂ ⊆ ⊃ ⊇ | `\in` `\notin` `\subset` `\subseteq` `\supset` `\supseteq` |
| ∪ ∩ ∖ ∅ | `\cup` `\cap` `\setminus` `\emptyset` |
| ∀ ∃ | `\forall` `\exists` |
| → ← ↔ ⇒ ⇐ ⇔ | `\to` `\leftarrow` `\leftrightarrow` `\Rightarrow` `\Leftarrow` `\Leftrightarrow` |
| ↦ | `\mapsto` |

`\to` 和 `\rightarrow` 是同一个箭头。推导用 `\Rightarrow`，映射用 `\to` 或 `\mapsto`。

```latex
f \colon X \to Y, \quad x \mapsto f(x)
A \subseteq B \iff x \in A \Rightarrow x \in B
```

`\colon` 是函数记号里的冒号，两侧间距比普通 `:` 合适。`\iff` 是带间距的 `⇔`。

逻辑连接：`\land`（∧）、`\lor`（∨）、`\neg`（¬）。

---

## 括号与定界符

手动写括号不会随内容变高。包住分式、矩阵时用 `\left` 和 `\right`，它们必须成对出现；某一侧不想显示时写 `\left.` 或 `\right.`。

```latex
\left( \frac{a}{b} \right)
\left[ \sum_{i=1}^{n} x_i \right]
\left. \frac{\partial f}{\partial x} \right|_{x=0}
```

常用定界符：`(` `)` `[` `]` `\{` `\}` `\langle` `\rangle` `|` `\|`。

`\lvert x \rvert`、`\lVert x \rVert`（需要 `amsmath`）是绝对值、范数的语义写法，间距比直接写 `|` 稳定。

---

## 矩阵

`amsmath` 按括号种类分环境。行用 `\\` 结束，列用 `&` 分开。

| 环境 | 括号 |
| --- | --- |
| `matrix` | 无 |
| `pmatrix` | ( ) |
| `bmatrix` | [ ] |
| `Bmatrix` | { } |
| `vmatrix` | \| \| |
| `Vmatrix` | \|\| \|\| |

```latex
\begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
\begin{bmatrix}
1 & 0 \\
0 & 1
\end{bmatrix}
```

省写相同元素用 `\cdots`（横）、`\vdots`（竖）、`\ddots`（斜）：

```latex
A = \begin{pmatrix}
a_{11} & \cdots & a_{1n} \\
\vdots & \ddots & \vdots \\
a_{n1} & \cdots & a_{nn}
\end{pmatrix}
```

---

## 多行对齐

`align` 在 `&` 处对齐，每行末尾 `\\`。不需要编号时用 `align*`。

```latex
\begin{align}
(a+b)^2 &= a^2 + 2ab + b^2 \\
        &= a^2 + b^2 + 2ab
\end{align}
```

分段函数用 `cases`。多条件对齐用 `aligned` 套在括号里。

```latex
f(x) = \begin{cases}
x^2 & x \ge 0 \\
-x  & x < 0
\end{cases}

\left\{
\begin{aligned}
x + y &= 1 \\
x - y &= 0
\end{aligned}
\right.
```

`cases` 里的条件默认是文本样式的数学模式，不等号直接写 `\ge` 即可。

---

## 字体与文字

| 用途 | 指令 | 例子 |
| --- | --- | --- |
| 粗体 | `\mathbf{v}` | 向量 |
| 黑板粗体 | `\mathbb{R}` | 实数集 |
| 花体 | `\mathcal{L}` | 拉格朗日量 |
| 罗马体 | `\mathrm{d}x` | 微分算子 d |
| 公式中的文字 | `\text{if }` | 条件说明 |

```latex
\mathbf{F} = m\mathbf{a}, \quad x \in \mathbb{R}^{n}
\mathcal{L}(q, \dot{q}) = T - V
\int f(x)\,\mathrm{d}x
```

`\text` 会按周围文字的字体排，适合 "for all"、"if"、"otherwise"。变量名不要用 `\text`，否则字母之间会按单词挤在一起。

向量也常见 `\vec{a}`（箭头）和 `\boldsymbol{\alpha}`（粗体希腊字母，需要 `amsmath`）。

---

## 省略号与修饰

| 效果 | 指令 |
| --- | --- |
| 底线上的点（逗号分隔） | `a_1, a_2, \ldots, a_n` |
| 居中的点（运算分隔） | `a_1 + a_2 + \cdots + a_n` |
| 上点、双点 | `\dot{x}` `\ddot{x}` |
| 上横线、帽子、波浪 | `\bar{x}` `\hat{x}` `\tilde{x}` |
| 向量箭头 | `\vec{v}` |
| 上下方括号标注 | `\overline{AB}` `\underline{x}` |
| 花括号标注 | `\overbrace{a+b}^{n}` `\underbrace{a+b}_{n}` |

列举用 `\ldots`，连加连乘中间用 `\cdots`。

---

## 间距

数学模式会忽略普通空格，间距靠指令：

| 指令 | 宽度 | 常见位置 |
| --- | --- | --- |
| `\,` | 窄 | `\,dx`、`3\, \mathrm{kg}` |
| `\:` | 中 | 少用 |
| `\;` | 宽 | 少用 |
| `\quad` | 1 em | 公式与条件之间 |
| `\qquad` | 2 em | 同一行两条公式之间 |

```latex
f(x) = x^2 \quad (x > 0)
```

---

## 一份能直接抄的例子

```latex
\documentclass{article}
\usepackage{amsmath,amssymb}

\begin{document}

行内勾股定理 $a^{2}+b^{2}=c^{2}$。

\begin{equation}
\sum_{k=0}^{n} \binom{n}{k} = 2^{n}
\end{equation}

\begin{align}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J}
\end{align}

\[
\sigma(z) = \frac{1}{1+e^{-z}}, \qquad
z \in \mathbb{R}
\]

\end{document}
```

`\binom{n}{k}` 是二项式系数。
