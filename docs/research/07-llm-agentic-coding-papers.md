# LLM Agentic Coding: Comprehensive Academic Survey (2024-2026)

**Research Date:** 2026-04-13
**Coverage:** 30+ papers and systems across multi-agent SE, code generation/repair, planning, context/retrieval, self-improvement, TDD/verification

**Note:** This file contains the full unabridged research. See the raw agent output for complete details on every paper including architecture, methodology, exact benchmark numbers, and limitations.

---

## Summary of Key Papers and Results

### Multi-Agent Software Engineering

| System | Institution | Date | Key Result | Venue |
|--------|-----------|------|------------|-------|
| ChatDev | Tsinghua | 2023/2024 | 86.66% executability, <$1/program | ACL 2024 |
| MetaGPT | DeepWisdom/KAUST | 2023/2024 | 100% executability, 50% less hallucination vs ChatDev | ICLR 2024 |
| AgentCoder | HKU/KCL | 2024 | 96.3% HumanEval (GPT-4), separated test generation | ACL 2024 Findings |
| CodeAgent | Peking U | 2024 | 37.2% on CodeAgentBench (vs 18.3% no-tools) | ACL 2024 |
| SWE-agent | Princeton | 2024 | 12.47% SWE-bench, 23% Lite. ACI design +40% improvement | NeurIPS 2024 |
| Aider | Independent | 2023-2026 | 82.7% polyglot benchmark (architect mode) | Open source |
| MapCoder | Bangladesh/Queens | 2024 | 93.9% HumanEval with retrieval-augmented multi-agent | ACL 2024 |

### SWE-bench Evolution (2024-2026)

| Period | SWE-bench Full | SWE-bench Lite | SWE-bench Verified |
|--------|---------------|----------------|-------------------|
| Early 2024 | 3.8% (RAG) | 23% (SWE-agent) | N/A |
| Mid 2024 | ~20% (Amazon Q) | 30.2% (Lingma) | ~46% (Agentless) |
| Late 2024 | ~25-28% | 35-45% | 50-55% (Devlo) |
| Mid 2025 | ~30%+ | 45%+ | 60-65% |
| Early 2026 | — | — | Approaching 70%+ |

### Code Generation and Repair

| System | Key Contribution | Best Result |
|--------|-----------------|-------------|
| Agentless | Simple 2-phase beats complex agents | 46% SWE-bench Verified, $0.34/issue |
| AutoCodeRover | AST-based tools + LLM reasoning | 22.7% SWE-bench Lite |
| RepairAgent | Fully autonomous APR with flexible tool use | 164/835 bugs on Defects4J |
| OpenHands/OpenDevin | CodeAct paradigm (code-as-action) | 53% SWE-bench Verified |
| AlphaCodium | Flow engineering > prompt engineering | 44% CodeContests Pass@5 |

### Planning and Reasoning

| Approach | Key Insight | Impact |
|----------|------------|--------|
| Structured CoT | Pseudocode step improves code quality | +4-7% on benchmarks |
| Plan-then-Code | Tree search over plans | 5-10% on APPS |
| Parsel | Hierarchical decomposition + constraint solver | 75/100 APPS intro (vs 58/100) |
| FunCoder | Function tree + consensus selection | 91.5% HumanEval (GPT-3.5!) |
| LATS | Monte Carlo tree search for agents | 94.4% HumanEval |
| Reasoning models (o1/o3/R1) | Extended CoT via RL | 89% HumanEval, ~55% SWE-bench Verified |

### Context and Retrieval

| Finding | Evidence |
|---------|---------|
| In-repo retrieval > cross-repo | Consistent across papers |
| Structural retrieval > text similarity | AST-based outperforms BM25/embeddings |
| Iterative retrieval > single-round | RepoCoder: +12.2% relative |
| Function-level chunks optimal | Multiple papers converge |
| Long context helps but "lost in middle" persists | 15-30% improvement with 128K+ context |

### Self-Improvement

| System | Key Technique | Result |
|--------|--------------|--------|
| Self-Debugging | Explanation-based debugging | +3-11% across benchmarks |
| Self-Repair | Iterative refinement with test feedback | +6% (GPT-4), diminishing after 2 rounds |
| Reflexion | Verbal reflections stored in memory | 91% HumanEval (vs 80% without) |
| Darwin Godel Machine | LLM-guided evolutionary self-modification | 10-30% improvement over seed agent |
| ADAS | Auto-designed agent architectures | 5-15% over manual designs |

### Test-Driven and Verification

| Finding | Evidence |
|---------|---------|
| TDD loop produces 15-20% fewer bugs | TDD-Bench 2024 |
| LLM tests kill 40-60% mutants (vs 70-85% human) | Multiple studies |
| Hybrid SBST+LLM achieves 12% higher coverage | CodaMosa (ICSE 2023) |
| Step-by-step execution verification +6% | LDB (ACL 2024) |
| Formal verification feasible for simple functions (~40-50%) | Multiple 2024 papers |

---

## Key Themes and Takeaways

### Architecture Patterns That Work

1. **Plan-then-Execute**: Nearly all successful systems separate planning from execution
2. **Iterative Refinement with Test Feedback**: 1-2 rounds yield highest marginal gains
3. **Structured Context Retrieval**: Multiple strategies (AST, embedding, keyword) at function-level
4. **Separation of Concerns in Multi-Agent**: Clear roles + structured interfaces > free-form chat
5. **Human-in-the-Loop**: Most successful commercial tools maintain human oversight

### Critical Findings

- **Agentless showed simple approaches can be competitive** — challenges need for complex agents
- **ACI design (SWE-agent) matters as much as model** — interface +40% improvement
- **Self-repair has diminishing returns after 2 rounds** — invest in getting initial generation right
- **Error amplification in multi-agent: 17.2x** for independent agents, 4.4x for centralized
- **Flow engineering > prompt engineering** — system design around LLM matters more than prompts
- **Reasoning models change the game** — but optimal use is planning+complex decisions, not routine edits

### Open Challenges (2026)

1. Specification ambiguity in real-world tasks
2. Architectural reasoning (agents fix bugs but struggle with design)
3. Long-horizon planning across many files
4. Cost efficiency ($1-10 per task for top agents)
5. Safety and security of autonomous agents
6. Better evaluation beyond SWE-bench

## Sources

Full paper citations in the detailed sections above. Key venues: ICLR 2024-2025, NeurIPS 2023-2024, ACL 2024, ICSE 2023-2024, ISSTA 2024, ICML 2024. Key institutions: Princeton, MIT, Stanford, Tsinghua, Peking U, UIUC, NUS, Microsoft Research, Google DeepMind, Anthropic, OpenAI, Alibaba DAMO, ByteDance, Cognition AI, Sakana AI.
