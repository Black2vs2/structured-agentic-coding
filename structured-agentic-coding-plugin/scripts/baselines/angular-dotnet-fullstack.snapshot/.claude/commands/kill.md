# Kill Dev Servers

Stop running development server processes.

## Parse the Request

Determine which processes to stop based on the user's message:

| User says | Action |
|-----------|--------|
| "kill backend", "stop backend", "stop api", "kill api" | Stop backend only |
| "kill frontend", "stop frontend", "stop serve" | Stop frontend only |
| "kill all", "stop all", "kill servers", "stop servers", "kill everything" | Stop both |

## Kill Commands

### Backend

```bash
# Windows
taskkill //F //IM dotnet.exe 2>/dev/null || echo "No backend processes found"

# Unix/Mac
pkill -f "dotnet.*run" 2>/dev/null || echo "No backend processes found"
```

### Frontend

```bash
# Windows — kill by port
for pid in $(netstat -aon 2>/dev/null | grep -E ':4200|:3000' | grep LISTENING | awk '{print $5}' | sort -u); do
  taskkill //F //PID "$pid" 2>/dev/null
done
# Fallback: kill all node processes related to dev server
taskkill //F //IM node.exe 2>/dev/null

# Unix/Mac
lsof -ti:4200,3000 2>/dev/null | xargs kill -9 2>/dev/null
pkill -f "serve" 2>/dev/null || echo "No frontend processes found"
```

## Execution

1. Detect the platform (check if running on Windows or Unix)
2. Run the appropriate kill command(s) via Bash
3. Report what was stopped

## Response Format

After killing processes, report briefly:
- "Stopped backend process."
- "Stopped frontend process."
- "No running processes found."
