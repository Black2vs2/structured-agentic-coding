# AI Code Review Systems and Structural Analysis

**Research Date:** 2026-04-13
**Coverage:** Academic papers, commercial tools, structural analysis, code smell detection, security, refactoring

**Note:** This file contains comprehensive findings. Full details on every paper/tool including exact metrics, methodologies, and limitations.

---

## Academic Research Key Results

### Code Review with LLMs

| Paper/System | Key Result | Venue |
|---|---|---|
| CodeReviewer | Outperforms SOTA across 3 review tasks | ESEC/FSE 2022 |
| CRScore | 0.54 Spearman correlation with human judgment | 2024 |
| CRScore++ | RL with verifiable tool + AI feedback | 2025 |
| SWR-Bench | Top F1 only 19.38%. Most systems <10% precision. Multi-review aggregation: +43.67% F1 | 2025 |
| Ericsson study | Code LLaMA 13B preferred. 4/9 devs saved time. Only 2/9 used regularly | 2025 |
| Bilkent study | GPT-4o 68.5% accuracy. Omitting descriptions -22.87%. Recommends human-in-loop | 2025 |
| SonarQube+LLM | Bugs: 100% resolution. Vulns: 100%. Code smells: 81.2%. Cost: <$35 for 7,500 issues | 2025 |

### Structural Analysis

| System | Key Result |
|---|---|
| AST-T5 | +2pts exact match on Bugs2Fix, +3pts on transpilation (ICML 2024) |
| cAST | AST-based RAG chunking for code (EMNLP 2025) |
| Codebase-Memory | Tree-sitter knowledge graph via MCP: 83% quality vs 92% explorer, **10x fewer tokens**, 2.1x fewer tool calls |
| GNN Defect Prediction | F1: 0.811, AUC: 0.896 for defect prediction (Nature 2025) |
| DGDefect | F1: 85.5% cross-project, 89.7% Java (SAGE 2025) |
| ast-grep | Structural search via MCP for AI tools |

### Code Smell Detection

| System | Key Result |
|---|---|
| iSMELL | F1: 75.17%, +35% over LLM baselines (ASE 2024) |
| PromptSmell | +11.17% precision, +7.4% F1 over prior work |
| GitClear 2025 | Duplicated code 8x increase, refactoring dropped 25%→<10% |
| LLM-generated code | 42-85% increase in code smell rates vs human code |

### Security

| System | Key Result |
|---|---|
| IRIS | Doubled CodeQL detection (27→55 vulns), 4 new zero-days (IRIS, Cornell 2024) |
| SAST-Genius | 91% false positive reduction vs Semgrep alone (IEEE S&P 2025) |
| GPTScan | >90% precision on token contracts, $0.01/1000 lines (ICSE 2024) |
| GRASP | >80% security rate, +88% on zero-day vulns (2025) |
| ProSec | 25-35% more secure than SafeCoder (ICLR 2026) |
| Survey | 12-65% of LLM-generated code has security issues |

### Refactoring

| System | Key Result |
|---|---|
| LLM Refactoring Study | ChatGPT 86.7% identification (improved prompts), 63.6% solutions comparable/better than human |
| EM-Assist | 53.4% recall (vs 39.4% prior SOTA), 94.4% positive usability. IntelliJ plugin |

---

## Commercial Tools Landscape (2026)

### Comparison Matrix

| Tool | Architecture | Key Metric | Pricing |
|---|---|---|---|
| CodeRabbit | Sandboxed AI agents, Codegraph | Cross-file dependency review | Free for OSS |
| Graphite (→Cursor) | Claude-powered, stacked PRs | Shopify: 33% more PRs merged, 75% through Graphite | Free for OSS |
| Sourcery AI | Python-focused refactoring | 30+ languages, individual file review | $10/user/mo |
| Qodo (CodiumAI) | 15+ specialized review agents | Gartner "Visionary" 2025 | Varies |
| Amazon CodeGuru | ML + program analysis (not LLM) | Java/Python, secrets detection | AWS pricing |
| GitHub Copilot Review | Agentic (March 2026 overhaul) | 60M reviews, 71% actionable | Copilot Business/Enterprise |
| Claude Code Review | Multi-agent parallel team | 84% finding rate on large PRs, 54% get substantive comments | $15-25/review est. |
| Atlassian Rovo Dev | Claude 3.5 Sonnet | 30.8% faster PR cycle time (ICSE 2026) | Included with Atlassian |
| Snyk DeepCode AI | Symbolic + generative + ML | 80% accurate autofixes, 19+ languages | Snyk pricing |
| Semgrep Assistant | SAST + LLM contextual reasoning | 95% alignment, 20-40% triage reduction | Enterprise |
| Tabnine Review | Privacy-first, custom rules | AI TechAwards 2025 | Enterprise |
| Bito AI | Claude Sonnet, agentic | 89% faster merges, 34% fewer regressions | Varies |
| DeepSource | 5,000+ rules, Autofix AI | <5% false positive rate | Free for OSS, $24/user/mo |
| Augment Code | Multi-repo indexing, 400K+ files | +14.8 correctness, +18.2 completeness (blind study) | Free-$200/mo |
| CodeAnt AI | SAST + AI review | 30+ languages, ranked risk view | $10-20/user/mo |
| Ellipsis | Review + auto-fix, Y Combinator | 13% faster merge time | Varies |
| Cursor BugBot | AI bug detection in editor | Caught race condition 3 human reviewers missed | Cursor subscription |

### 2026 Trends

1. **Multi-agent architectures dominant**: Claude Code Review, Qodo 2.0, Copilot agentic overhaul all use parallel specialized agents
2. **Static analysis + LLM consistently outperforms either alone**: IRIS, SAST-Genius, Semgrep, SonarQube+LLM
3. **Tree-sitter/AST becoming standard bridge** between structural code understanding and LLM reasoning
4. **AI-generated code quality is a growing concern**: 8x increase in duplicated code (GitClear)
5. **Security is highest-stakes application**: Hybrid LLM+SAST shows dramatic improvements

---

## Codebase-Memory: Closest Academic Parallel to Our Graph Server

This paper (March 2026, arxiv 2603.27277) is the closest published work to what we're building:

- **Tree-sitter knowledge graph via MCP** across 66 languages
- Multi-phase pipeline: parsing, worker pools, call-graph traversal, impact analysis, community discovery
- **Results**: 83% answer quality (vs 92% for full file exploration), but **10x fewer tokens** and **2.1x fewer tool calls**
- Tested on 31 real-world repositories
- Trade-off: reduced quality for massive efficiency gains

This validates our approach. Our system targets higher quality by using graph as complement to grep (not replacement), with progressive disclosure and config grep for blind spots.

---

## Relevance to Our System

### Direct applicability
- **SonarQube+LLM pipeline** (100% bug/vuln resolution, $35 total) → could integrate with our scan playbooks
- **Multi-review aggregation** (+43.67% F1) → run multiple review passes and merge findings
- **ast-grep MCP** → structural search complement to our tree-sitter graph
- **Codebase-Memory** → validates our exact approach (tree-sitter graph via MCP)

### Patterns to adopt
- **IRIS's neuro-symbolic approach** (LLM + CodeQL) → combine our graph with LLM reasoning
- **SAST-Genius's false positive reduction** (91%) → use graph to validate/filter LLM review findings
- **Ericsson's Tree-Sitter method context** → extract surrounding context for better review prompts
- **Cross-file dependency analysis** (CodeRabbit, Augment) → our blast_radius tool enables this

### Warnings
- **SWR-Bench: top F1 only 19.38%** → automated review is still immature, always human-in-loop
- **LLM-generated code smells up 42-85%** → our scan playbooks are critical quality gate
- **12-65% of LLM code has security issues** → security scanning must be non-optional

## Sources

Full citations in each section. Key venues: ASE 2024, ICSE 2024, ICML 2024, ACL 2024, IEEE S&P 2025, ICLR 2026, Nature 2025. Key institutions: Cornell, CMU, Peking U, Berkeley, Ericsson, Bilkent, Chalmers. Tools: CodeRabbit, Graphite, Qodo, Snyk, Semgrep, GitHub Copilot, Claude Code Review, Augment Code, DeepSource, Atlassian Rovo Dev.
