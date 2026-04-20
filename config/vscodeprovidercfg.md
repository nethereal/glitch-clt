### Updated VS Code "Continue" Configuration for Qwen 3.6 TurboQuant

Use this version for the best balance between **Long Context**, **Tool Calling**, and **Repetition Fixes**.

```json
{
  "models": [
    {
      "title": "Qwen 3.6 Turbo",
      "model": "qwen3.6-35b-a3b-iq4xs",
      "apiBase": "http://localhost:9998",
      "provider": "llama-cpp",
      "contextLength": 131072,
      "completionOptions": {
        "stop": [
          "<|im_end|>",
          "<|im_start|>",
          "<|endoftext|>"
        ],
        "temperature": 0.2,
        "maxTokens": 4096
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen 3.6 Turbo (Auto)",
    "model": "qwen3.6-35b-a3b-iq4xs",
    "apiBase": "http://localhost:9998",
    "provider": "llama-cpp",
    "contextLength": 16384,
    "completionOptions": {
      "stop": [
        "<|im_end|>",
        "<|im_start|>",
        "<|endoftext|>"
      ]
    }
  }
}
```

#### Key Adjustments:
1.  **Provider `llama-cpp`**: Using the native provider instead of generic `openai` helps the extension handle the "Reasoning" and "Tool Call" tags more reliably with your specific server build.
2.  **Context Length (`131072`)**: Since your 3090 is now optimized with **TurboQuant** and **MLA**, you can comfortably use 128k context in VS Code without hitting VRAM limits.
3.  **API Base**: Noted that for the `llama-cpp` provider in Continue, you often just use the base URL `http://localhost:9998` (without the `/v1`).
