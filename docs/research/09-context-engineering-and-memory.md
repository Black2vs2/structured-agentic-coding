# Context Engineering, Memory, and Token Optimization for AI Coding Agents

**Research Date:** 2026-04-13
**Coverage:** Anthropic official guide, academic surveys (1,400+ papers), production systems (Manus, Factory, JetBrains), memory frameworks, repository understanding, token economics, compression, session management

---

## 1. Core Principles

### Anthropic's Official Definition
"Context engineering is curating and maintaining the optimal set of tokens during LLM inference." Guiding principle: "the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."

### Why It Matters Technically
LLMs exhibit "context rot" — performance degrades as context increases due to transformer's n-squared pairwise token relationships. Every new token depletes the model's "attention budget."

### Karpathy's Framing (June 2025)
"The LLM is a CPU, the context window is RAM, and your job is loading working memory with the right code and data." Agent failures are not model failures — they are context failures.

---

## 2. Five Effective Context Components (Anthropic)

1. **System Prompts** — "Right altitude" (Goldilocks zone). Too rigid = brittleness. Too vague = insufficient signals. Use XML tags/Markdown headers. Start minimal, iterate on failures.

2. **Tools** — Self-contained, error-robust, unambiguous. Minimal overlap. A human should definitively identify which tool applies.

3. **Examples (Few-Shot)** — Curate diverse canonical examples rather than exhaustive edge-case lists. "Pictures worth a thousand words."

4. **Just-In-Time Context Retrieval** — Maintain lightweight identifiers (file paths, queries). Dynamically load at runtime. Progressive disclosure.

5. **Long-Horizon Techniques:**
   - **Compaction**: Summarize near limits, reinitialize. Clear old tool results.
   - **Structured Note-Taking**: Agent writes externally-persisted notes pulled back into context.
   - **Sub-Agent Architectures**: Specialized sub-agents return 1,000-2,000 token summaries despite using tens of thousands internally.

---

## 3. Context Rot and Degradation Evidence

### NoLiMa Benchmark (Adobe Research, ICLR)
At 32K tokens, 11/12 models dropped below 50% of short-context baselines. GPT-4o: 99.3% → 69.7%.

### Chroma Research (18 models tested)
- Models do NOT use context uniformly; performance grows increasingly unreliable with length
- Even one distractor reduces performance
- **Shuffled haystacks outperform coherent ones** (counter-intuitive: structured text is harder to search)
- Claude: lowest hallucination rates, conservative abstentions
- GPT: highest hallucination rates with distractors

| Model | 8K | 32K | 120K | 192K |
|-------|-----|------|------|------|
| Gemini 2.5 Pro | 80.6 | 91.7 | 87.5 | 90.6 |
| GPT-5 | 100.0 | 97.2 | 96.9 | 87.5 |
| Claude Sonnet 4 (Thinking) | 97.2 | 91.7 | 81.3 | — |

---

## 4. Compression Techniques

### LLMLingua (Microsoft Research, EMNLP 2023 / ACL 2024)
- Up to 20x compression with only 1.5-point performance loss
- 1.7x to 5.7x inference acceleration
- LongLLMLingua: 21.4% boost with 4x fewer tokens

### CCF: Context Compression Framework
- 8x compression: ROUGE-L 0.97-1.00
- 128K context: 3x faster decoding, **30x reduction in KV-cache memory** (2GB vs 64GB)
- Perfect needle-in-haystack at 8x compression

### Observation Masking (JetBrains Research, Dec 2025)
SWE-bench Verified, 500 instances, up to 250 turns:
- **52% cheaper** while improving solve rates by 2.6%
- Outperformed LLM summarization in 4/5 settings
- **Unexpected:** Summarization caused agents to run 13-15% longer — "summaries may smooth over signs the agent should stop"
- Summary API calls added 7%+ to costs

### Factory.ai Anchored Iterative Summarization
36,000+ production messages evaluated:
- Factory (anchored): 3.70 overall score
- Anthropic compaction: 3.44
- OpenAI /responses/compact: 3.35
- "The right optimization target is not tokens per request. It is tokens per task."

---

## 5. Production Context Architectures

### Manus AI (rebuilt framework 4 times)

1. **KV-Cache Optimization** (most important): Input:output ratio averages 100:1. Cached tokens: $0.30/MTok vs $3/MTok uncached (10x savings). Keep prefixes stable — single-token diff invalidates cache. No timestamps in system prompts.

2. **Mask Rather Than Remove Tools**: Dynamic removal breaks cache and confuses models. Use state machines to mask token logits during decoding.

3. **File System as Extended Memory**: Unlimited, persistent, directly-operable context. Average task: ~50 tool calls.

4. **Todo Recitation**: Agents create/update todo.md pushing objectives into recent attention span. Prevents "lost-in-the-middle" drift.

5. **Preserve Error Traces**: Failed actions and stack traces in context. Model implicitly updates beliefs.

### Google Agent Development Kit (ADK)

Three-pillar architecture:
1. **Structure**: Working Context → Session → Memory → Artifacts. Processors form compiler pipeline.
2. **Relevance**: Artifacts as handles, semantic retrieval via load_memory_tool, context compaction at thresholds.
3. **Multi-Agent Scoping**: "Agents as Tools" (focused prompts), "Agent Transfer" (configurable inclusion: full/partial/none).

### Anthropic Harnesses for Long-Running Agents

Two-part: Initializer Agent (creates init.sh, progress tracking, feature list as JSON) + Coding Agent (reads state via git logs, selects single feature, commits, updates progress). Critical: "It is unacceptable to remove or edit tests."

---

## 6. Memory Systems

### MemGPT (UC Berkeley)
Virtual context management inspired by OS memory hierarchies:
- Tier 1 (Main Context): Standard fixed window
- Tier 2 (External Context): Vector databases (LanceDB)
- Self-editing memory through function calls

### A-MEM (NeurIPS 2025)
Zettelkasten-inspired: interconnected knowledge networks through dynamic indexing and linking. New entries trigger updates to existing representations.

### Synapse: Episodic-Semantic Memory (Best Results)
- Dual-layer graph: episodic nodes (interactions) + semantic nodes (concepts)
- Spreading activation with temporal decay
- **40.5 F1** on LoCoMo (rank 1), vs Zep 39.7, MemoryOS 38.0
- **95% token reduction** (~814 tokens/query vs 16,910 full-context)
- 4x faster, 11x cheaper
- Ablation: removing node decay destroys temporal reasoning (50.1 → 14.2 F1)

### Practical Implementations
- **CLAUDE.md / AGENTS.md**: File-based, read at session start
- **Engram**: Go + SQLite + FTS5, MCP server
- **Mem0**: Auto-extracts memories using Qdrant vector DB
- **OMEGA**: Fully on-device, no cloud

---

## 7. Repository Understanding

### Aider Repository Map
- Tree-sitter AST → function/class signatures
- Directed graph with PageRank (personalized by chat context)
- Default 1,000 token budget
- Dynamically adjusts size based on chat state

### Cursor Codebase Indexing (5-step)
1. Local chunking (fixed, recursive, AST-based)
2. Merkle tree construction for change detection
3. Embedding generation
4. Vector storage in Turbopuffer (path-obfuscated)
5. Incremental updates every 5-10 minutes

### Augment Code Context Engine
- Indexes 1M+ files with knowledge graph
- Curates 4,456+ sources → 682 relevant items
- Blind study: +14.8 correctness, +18.2 completeness vs competitors
- "Context architecture matters as much or more than model choice"

### GrepRAG: Grep vs Embeddings (Critical Finding)
- Ripgrep: ~0.40 seconds on 754K LOC repo
- GraphCoder: 3-7 seconds (35x slower)
- **Grep succeeded in 161 cases where ALL embedding baselines failed** (11.6% unique contribution)
- Embedding recall failures: 64-73% on cases grep handles
- "Failure mode of grep is loud (no match) vs RAG's silent (wrong match)"

### Knowledge Graph Repository Code Generation (Northeastern/Quantiphi)
- AST extraction → Neo4j with dual indexing
- Claude 3.5 Sonnet: 36.36% pass@1 (vs 7.27% without context)
- "What depends on X?" goes from ~6,000 tokens to ~200 tokens via graph lookup

### Codebase-Memory (March 2026, closest to our approach)
- Tree-sitter knowledge graph via MCP, 66 languages
- 83% quality vs 92% explorer, **10x fewer tokens**, 2.1x fewer tool calls
- 31 real-world repositories tested

---

## 8. Token Economics

### The Cost Problem
- Multi-agent: quadratic token growth. Reflexion at 10 cycles = 50x single pass
- Agents make 3-10x more LLM calls than chatbots per request
- Single request can trigger 5x the token budget (planning + tool selection + execution + verification + response)
- MCP tool definitions alone: Playwright 11.7K tokens, built-in tools 11.6K

### Cost Optimization Techniques

**Multi-Model Routing (MoMA Framework):**
- 12 models, 20+ specialized agents
- Comparable performance with **31.46% cost reduction**
- 60-70% queries handled by small models (8-20x cost difference)

**CascadeFlow:**
- 40-85% cost reduction, 2-10x faster
- Well-implemented: 87% cost reduction, expensive models handle only ~10%

**Agentic Plan Caching:**
- Cache plan templates from completed executions
- **50.31% cost reduction**, 27.28% latency reduction, 96.61% performance maintained

**Speculative Decoding:**
- 2-3x inference speedup, zero accuracy loss
- SWE-Bench agents: 1.8-4.5x end-to-end speedup
- Google uses it for AI Overviews in Search

**Dynamic Turn Limits:**
- Based on success probability
- 24% cost cut while maintaining solve rates

**Input Token Caching:**
- Reduces costs to $0.02/MTok (~10x cheaper)
- Critical for KV-cache-friendly prompt design

---

## 9. Session Management

### Microsoft Agent Framework: 5 Compaction Strategies
1. **Truncation**: Remove oldest non-system messages
2. **Sliding Window**: Keep last N turns
3. **Tool Result Compaction**: Collapse older tool calls to summaries
4. **Summarization**: LLM-based summary of older portions
5. **Pipeline**: Compose strategies gentle → aggressive

### Key Design Patterns
- **CompactionTrigger system**: TokensExceed, MessagesExceed, TurnsExceed
- **MessageGroup atomicity**: Tool calls + results kept/removed together
- **Two-threshold system** (Factory): T_max (fill line) and T_retained (drain line)
- **Anchored iterative** (Factory): New compressions merge into existing summaries rather than regenerating

---

## 10. Academic Survey (1,400+ papers)

**"A Survey of Context Engineering for LLMs"** (July 2025, Chinese Academy of Sciences et al.)

Documented performance gains:
- 18x enhancement in text navigation accuracy
- 94% success rates in RAG
- 9.90% BLEU-4 for code summarization
- 175.96% exact match for bug fixing
- 9.8% on code generation benchmarks

Critical finding: "Models demonstrate remarkable proficiency in understanding complex contexts, yet exhibit pronounced limitations in generating equally sophisticated, long-form outputs."

---

## Key Takeaways for Our System

1. **Graph + grep is the right architecture** — validated by GrepRAG, Codebase-Memory, and industry practice
2. **Observation masking > LLM summarization** for cost reduction (JetBrains: 52% cheaper, better performance)
3. **KV-cache optimization is the #1 cost lever** — stable prefixes, no timestamps, append-only (Manus)
4. **Progressive disclosure works** — Anthropic, Google ADK, skills all converge on this
5. **Context rot is real** — performance drops at 32K+ tokens. Keep context lean.
6. **Sub-agent architectures are the compounding solution** — each gets fresh 200K window
7. **Grep beats embeddings for code** — louder failure mode, 35x faster, works immediately
8. **Plan caching could save 50% costs** — cache masterplan templates from completed executions
9. **Multi-model routing saves 31-87%** — route simple tasks to cheap models
10. **Todo recitation prevents lost-in-middle** — agents maintain their own attention anchors

## Sources

Full citations throughout each section. Key sources: Anthropic engineering blog, Manus AI blog, Google Developers Blog, JetBrains Research, Factory.ai, Chroma Research, Microsoft Agent Framework, arXiv papers (2310.08560, 2502.12110, 2601.02744, 2507.13334, 2510.04618, 2502.05167, 2509.09199, 2509.07571, 2601.23254, 2505.14394, 2504.09775), MindStudio analysis, Aider docs, Cursor docs, Sourcegraph docs, Augment Code docs.
