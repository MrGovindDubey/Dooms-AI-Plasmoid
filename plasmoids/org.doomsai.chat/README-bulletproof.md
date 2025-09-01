# Dooms AI Plasmoid: Bulletproof User Experience

## For All Users

To ensure the AI assistant is always ready instantly after login (no delays, no stuck initializing):

**Enable Ollama service at login:**
```bash
systemctl --user enable ollama
systemctl --user start ollama
```
This ensures the backend is running before you use the plasmoid.

## Improvements
- Faster startup (less waiting)
- Clearer error feedback if backend fails
- No change to core logic or features

## Troubleshooting
If you ever see "Initializing" or "Setup failed", check that the Ollama service is running:
```bash
systemctl --user status ollama
```
If not, start it:
```bash
systemctl --user start ollama
```
