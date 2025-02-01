<div align="center">

# parrot.nvim 🦜

This is [parrot.nvim](https://github.com/frankroeder/parrot.nvim), the ultimate [stochastic parrot](https://en.wikipedia.org/wiki/Stochastic_parrot) to support your text editing inside Neovim.

[Features](#features) • [Demo](#demo) • [Getting Started](#getting-started) • [Commands](#commands) • [Configuration](#configuration) • [Roadmap](#roadmap) • [FAQ](#faq)

<img src="https://github.com/frankroeder/parrot.nvim/assets/19746932/b19c5260-1713-400a-bd55-3faa87f4b509" alt="parrot.nvim logo" width="50%">
</div>

## Features

[parrot.nvim](https://github.com/frankroeder/parrot.nvim) offers a seamless out-of-the-box experience, providing tight integration of current LLM APIs into your Neovim workflows, with a focus solely on text generation.
The selected core features include on-demand text completion and editing, as well as chat-like sessions within native Neovim buffers.
While this project is still under development, a substantial part of the code is based on an early fork of the brilliant work by Tibor Schmidt's [gp.nvim](https://github.com/Robitx/gp.nvim).

- Persistent conversations stored as markdown files within Neovim's standard path or a user-defined location
- Custom hooks for inline text editing based on user instructions and chats with predefined system prompts
- Support for multiple providers:
    + [Anthropic API](https://www.anthropic.com/api)
    + [Perplexity.ai API](https://blog.perplexity.ai/blog/introducing-pplx-api)
    + [OpenAI API](https://platform.openai.com/)
    + [Mistral API](https://docs.mistral.ai/api/)
    + [Gemini API](https://ai.google.dev/gemini-api/docs)
    + [Groq API](https://console.groq.com)
    + Local and offline serving via [ollama](https://github.com/ollama/ollama)
    + [GitHub Models](https://github.com/marketplace/models)
    + [NVIDIA API](https://docs.api.nvidia.com)
    + [xAI API](https://console.x.ai) for **Grok**
- Flexible API credential management from various sources:
    + Environment variables
    + Bash commands
    + Password manager CLIs (lazy evaluation)
- Repository-specific instructions via `.parrot.md` file using the `PrtContext` command
- **No** autocompletion and **no** hidden requests in the background to analyze your files


## Demo

Seamlessly switch between providers and models.
<div align="left">
    <p>https://github.com/user-attachments/assets/0df0348f-85c0-4a2d-ba1f-ede2738c6d02</p>
</div>

---

Trigger code completions based on comments.
<div align="left">
    <p>https://github.com/user-attachments/assets/197f99ac-9854-4fe9-bddb-394c1b64f6b6</p>
</div>

---

Let the parrot fix your bugs.
<div align="left">
    <p>https://github.com/user-attachments/assets/d3a0b261-a9dd-45e6-b508-dc5280594b06</p>
</div>

---

<details>
<summary>Rewrite a visual selection with `PrtRewrite`.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/c3d38702-7558-4e9e-96a3-c43312a543d0</p>
</div>
</details>

---

<details>
<summary>Append code with the visual selection as context with `PrtAppend`.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/80af02fa-cd88-4023-8a55-f2d3c0a2f28e</p>
</div>
</details>

---

<details>
<summary>Add comments to a function with `PrtPrepend`.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/9a6bfe66-4bc7-4b63-8694-67bf9c23c064</p>
</div>
</details>

---

<details>
<summary>Retry your latest rewrite, append or prepend with `PrtRetry`.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/03442f34-687b-482e-b7f1-7812f70739cc</p>
</div>
</details>

## Getting Started

### Dependencies

This plugin requires the latest version of Neovim and relies on a carefully selected set of established plugins.

- [`neovim 0.10+`](https://github.com/neovim/neovim/releases)
- [`plenary`](https://github.com/nvim-lua/plenary.nvim)
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) (optional)
- [`fzf`](https://github.com/junegunn/fzf) (optional, requires ripgrep)
- [`telescope`](https://github.com/nvim-telescope/telescope.nvim) (optional)

### Installation

<details>
  <summary>lazy.nvim</summary>


```lua
{
  "frankroeder/parrot.nvim",
  dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim" },
  opts = {}
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require("packer").startup(function()
  use({
    "frankroeder/parrot.nvim",
    requires = { 'ibhagwan/fzf-lua', 'nvim-lua/plenary.nvim'},
    config = function()
      require("parrot").setup()
    end,
  })
end)
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/frankroeder/parrot.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/parrot/start/parrot.nvim
```

</details>

### Setup

The minimal requirement is to at least set up one provider, hence one from the selection below.

```lua
{
  "frankroeder/parrot.nvim",
  dependencies = { 'ibhagwan/fzf-lua', 'nvim-lua/plenary.nvim' },
  -- optionally include "rcarriga/nvim-notify" for beautiful notifications
  config = function()
    require("parrot").setup {
      -- Providers must be explicitly added to make them available.
      providers = {
        anthropic = {
          api_key = os.getenv "ANTHROPIC_API_KEY",
        },
        gemini = {
          api_key = os.getenv "GEMINI_API_KEY",
        },
        groq = {
          api_key = os.getenv "GROQ_API_KEY",
        },
        mistral = {
          api_key = os.getenv "MISTRAL_API_KEY",
        },
        pplx = {
          api_key = os.getenv "PERPLEXITY_API_KEY",
        },
        -- provide an empty list to make provider available (no API key required)
        ollama = {},
        openai = {
          api_key = os.getenv "OPENAI_API_KEY",
        },
        github = {
          api_key = os.getenv "GITHUB_TOKEN",
        },
        nvidia = {
          api_key = os.getenv "NVIDIA_API_KEY",
        },
        xai = {
          api_key = os.getenv "XAI_API_KEY",
        },
      },
    }
  end,
}
```

## Commands

Below are the available commands that can be configured as keybindings.
These commands are included in the default setup.
Additional useful commands are implemented through hooks (see below).

### General
| Command                   | Description                                   |
| ------------------------- | ----------------------------------------------|
| `PrtChatNew <target>`     | Open a new chat                               |
| `PrtChatToggle <target>`  | Toggle chat (open last chat or new one)       |
| `PrtChatPaste <target>`   | Paste visual selection into the latest chat   |
| `PrtInfo`                 | Print plugin config                           |
| `PrtContext <target>`     | Edits the local context file                  |
| `PrtChatFinder`           | Fuzzy search chat files using fzf             |
| `PrtChatDelete`           | Delete the current chat file                  |
| `PrtChatRespond`          | Trigger chat respond (in chat file)           |
| `PrtStop`                 | Interrupt ongoing respond                     |
| `PrtProvider <provider>`  | Switch the provider (empty arg triggers fzf)  |
| `PrtModel <model>`        | Switch the model (empty arg triggers fzf)     |
| `PrtStatus`               | Prints current provider and model selection   |
|  __Interactive__          | |
| `PrtRewrite`              | Rewrites the visual selection based on a provided prompt |
| `PrtEdit`                 | Like `PrtRewrite` but you can change the last prompt |
| `PrtAppend`               | Append text to the visual selection based on a provided prompt    |
| `PrtPrepend`              | Prepend text to the visual selection based on a provided prompt   |
| `PrtNew`                  | Prompt the model to respond in a new window   |
| `PrtEnew`                 | Prompt the model to respond in a new buffer   |
| `PrtVnew`                 | Prompt the model to respond in a vsplit       |
| `PrtTabnew`               | Prompt the model to respond in a new tab      |
| `PrtRetry`                | Repeats the last rewrite/append/prepend       |
|  __Example Hooks__        | |
| `PrtImplement`            | Takes the visual selection as prompt to generate code |
| `PrtAsk`                  | Ask the model a question                      |

With `<target>`, we indicate the command to open the chat within one of the following target locations (defaults to `toggle_target`):

- `popup`: open a popup window which can be configured via the options provided below
- `split`: open the chat in a horizontal split
- `vsplit`: open the chat in a vertical split
- `tabnew`: open the chat in a new tab

All chat commands (`PrtChatNew, PrtChatToggle`) and custom hooks support the
visual selection to appear in the chat when triggered.
Interactive commands require the user to make use of the [template placeholders](#template-placeholders)
to consider a visual selection within an API request.

## Configuration

### Options

```lua
{
    -- The provider definitions include endpoints, API keys, default parameters,
    -- and topic model arguments for chat summarization, with an example provided for Anthropic.
    providers = {
      anthropic = {
        api_key = os.getenv("ANTHROPIC_API_KEY"),
        -- OPTIONAL: Alternative methods to retrieve API key
        -- Using GPG for decryption:
        -- api_key = { "gpg", "--decrypt", vim.fn.expand("$HOME") .. "/anthropic_api_key.txt.gpg" },
        -- Using macOS Keychain:
        -- api_key = { "/usr/bin/security", "find-generic-password", "-s anthropic-api-key", "-w" },
        endpoint = "https://api.anthropic.com/v1/messages",
        topic_prompt = "You only respond with 3 to 4 words to summarize the past conversation.",
        -- usually a cheap and fast model to generate the chat topic based on
        -- the whole chat history
        topic = {
          model = "claude-3-haiku-20240307",
          params = { max_tokens = 32 },
        },
        -- default parameters for the actual model
        params = {
          chat = { max_tokens = 4096 },
          command = { max_tokens = 4096 },
        },
      },
      ...
    }

    -- default system prompts used for the chat sessions and the command routines
    system_prompt = {
      chat = ...,
      command = ...
    },

    -- the prefix used for all commands
    cmd_prefix = "Prt",

    -- optional parameters for curl
    curl_params = {},

    -- The directory to store persisted state information like the
    -- current provider and the selected models
    state_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/persisted",

    -- The directory to store the chats (searched with PrtChatFinder)
    chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/chats",

    -- Chat user prompt prefix
    chat_user_prefix = "🗨:",

    -- llm prompt prefix
    llm_prefix = "🦜:",

    -- Explicitly confirm deletion of a chat file
    chat_confirm_delete = true,

    -- When available, call API for model selection
    online_model_selection = false,

    -- Local chat buffer shortcuts
    chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g><C-g>" },
    chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
    chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>s" },
    chat_shortcut_new = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>c" },

    -- Option to move the cursor to the end of the file after finished respond
    chat_free_cursor = false,

     -- use prompt buftype for chats (:h prompt-buffer)
    chat_prompt_buf_type = false,

    -- Default target for  PrtChatToggle, PrtChatNew, PrtContext and the chats opened from the ChatFinder
    -- values: popup / split / vsplit / tabnew
    toggle_target = "vsplit",

    -- The interactive user input appearing when can be "native" for
    -- vim.ui.input or "buffer" to query the input within a native nvim buffer
    -- (see video demonstrations below)
    user_input_ui = "native",

    -- Popup window layout
    -- border: "single", "double", "rounded", "solid", "shadow", "none"
    style_popup_border = "single",

    -- margins are number of characters or lines
    style_popup_margin_bottom = 8,
    style_popup_margin_left = 1,
    style_popup_margin_right = 2,
    style_popup_margin_top = 2,
    style_popup_max_width = 160

    -- Prompt used for interactive LLM calls like PrtRewrite where {{llm}} is
    -- a placeholder for the llm name
    command_prompt_prefix_template = "🤖 {{llm}} ~ ",

    -- auto select command response (easier chaining of commands)
    -- if false it also frees up the buffer cursor for further editing elsewhere
    command_auto_select_response = true,

    -- fzf_lua options for PrtModel and PrtChatFinder when plugin is installed
    fzf_lua_opts = {
        ["--ansi"] = true,
        ["--sort"] = "",
        ["--info"] = "inline",
        ["--layout"] = "reverse",
        ["--preview-window"] = "nohidden:right:75%",
    },

    -- Enables the query spinner animation 
    enable_spinner = true,
    -- Type of spinner animation to display while loading
    -- Available options: "dots", "line", "star", "bouncing_bar", "bouncing_ball"
    spinner_type = "star",
}
```

#### Demonstrations

<details>
<summary>With <code>user_input_ui = "native"</code>, use <code>vim.ui.input</code> as slim input interface.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/c2fe3bde-a35a-4f2a-957b-687e4f6f2e5c</p>
</div>
</details>

<details>
<summary>With <code>user_input_ui = "buffer"</code>, your input is simply a buffer. All of the content is passed to the API when closed.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/63e6e1c4-a2ab-4c60-9b43-332e4b581360</p>
</div>
</details>

<details>
<summary>The spinner is a useful indicator for providers that take longer to respond.</summary>
<div align="left">
    <p>https://github.com/user-attachments/assets/ebcd27cb-da00-4150-a0f8-1d2e1afa0acb</p>
</div>
</details>


### Key Bindings

This plugin provides the following default key mappings:

| Keymap       | Description                                                 |
|--------------|-------------------------------------------------------------|
| `<C-g>c`     | Opens a new chat via `PrtChatNew`                           |
| `<C-g><C-g>` | Trigger the API to generate a response via `PrtChatRespond` |
| `<C-g>s`     | Stop the current text generation via `PrtStop`              |
| `<C-g>d`     | Delete the current chat file via `PrtChatDelete`            |

### Adding a new command

#### Ask a single-turn question and receive the answer in a popup window

```lua
require("parrot").setup {
    -- ...
    hooks = {
      Ask = function(parrot, params)
        local template = [[
          In light of your existing knowledge base, please generate a response that
          is succinct and directly addresses the question posed. Prioritize accuracy
          and relevance in your answer, drawing upon the most recent information
          available to you. Aim to deliver your response in a concise manner,
          focusing on the essence of the inquiry.
          Question: {{command}}
        ]]
        local model_obj = parrot.get_model("command")
        parrot.logger.info("Asking model: " .. model_obj.name)
        parrot.Prompt(params, parrot.ui.Target.popup, model_obj, "🤖 Ask ~ ", template)
      end,
    }
    -- ...
}
```

#### Start a chat with a predefined chat prompt to check your spelling.

```lua
require("parrot").setup {
    -- ...
    hooks = {
      SpellCheck = function(prt, params)
        local chat_prompt = [[
          Your task is to take the text provided and rewrite it into a clear,
          grammatically correct version while preserving the original meaning
          as closely as possible. Correct any spelling mistakes, punctuation
          errors, verb tense issues, word choice problems, and other
          grammatical mistakes.
        ]]
        prt.ChatNew(params, chat_prompt)
      end,
    }
    -- ...
}
```

Refer to my [personal lazy.nvim setup](https://github.com/frankroeder/dotfiles/blob/master/nvim/lua/plugins/parrot.lua) or
those of [other users](https://github.com/search?utf8=%E2%9C%93&q=frankroeder%2Fparrot.nvim+language%3ALua&type=code&l=Lua) for further hooks and key bindings.

### Template Placeholders

Users can utilize the following placeholders in their hook and system templates to inject
additional context:

| Placeholder             | Content                              |
|-------------------------|--------------------------------------|
| `{{selection}}`         | Current visual selection             |
| `{{filetype}}`          | Filetype of the current buffer       |
| `{{filepath}}`          | Full path of the current file        |
| `{{filecontent}}`       | Full content of the current buffer   |
| `{{multifilecontent}}`  | Full content of all open buffers     |

Below is an example of how to use these placeholders in a completion hook, which
receives the full file context and the selected code snippet as input.


```lua
require("parrot").setup {
    -- ...
    hooks = {
      CompleteFullContext = function(prt, params)
        local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{filecontent}}
        ```

        Please look at the following section specifically:
        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted.
        ]]
        local model_obj = prt.get_model("command")
        prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
      end,
    }
    -- ...
}
```

The placeholders `{{filetype}}` and  `{{filecontent}}` can also be used in the `chat_prompt` when
creating custom hooks calling `prt.ChatNew(params, chat_prompt)` to directly inject the whole file content.

```lua
require("parrot").setup {
    -- ...
      CodeConsultant = function(prt, params)
        local chat_prompt = [[
          Your task is to analyze the provided {{filetype}} code and suggest
          improvements to optimize its performance. Identify areas where the
          code can be made more efficient, faster, or less resource-intensive.
          Provide specific suggestions for optimization, along with explanations
          of how these changes can enhance the code's performance. The optimized
          code should maintain the same functionality as the original code while
          demonstrating improved efficiency.

          Here is the code
          ```{{filetype}}
          {{filecontent}}
          ```
        ]]
        prt.ChatNew(params, chat_prompt)
      end,
    }
    -- ...
}
```

## Statusline Support

Knowing the current chat or command model can be shown using your favorite statusline plugin.
Below, we provide an example for [lualine](https://github.com/nvim-lualine/lualine.nvim):

```lua
  -- define function and formatting of the information
  local function parrot_status()
    local status_info = require("parrot.config").get_status_info()
    local status = ""
    if status_info.is_chat then
      status = status_info.prov.chat.name
    else
      status = status_info.prov.command.name
    end
    return string.format("%s(%s)", status, status_info.model)
  end

  -- add to lueline section
  require('lualine').setup {
    sections = {
      lualine_a = { parrot_status }
  }

```

## Adding a custom provider
In case your provider is not available, there is an option to resuse a present
provider with a different endpoint and a custom selection of models.
For this, the `custom` provider needs to be added to the list of providers the following way:
```lua
  providers = {
    custom = {
      style = "openai",
      api_key = os.getenv "CUSTOM_API_KEY",
      endpoint = "https://api.openai.com/v1/chat/completions",
      models = {
        "gpt-4o-mini",
        "gpt-4o",
      },
      -- parameters to summarize chat
      topic = {
        model = "gpt-4o-mini",
        params = { max_completion_tokens = 64 },
      },
      -- default parameters
      params = {
        chat = { temperature = 1.1, top_p = 1 },
        command = { temperature = 1.1, top_p = 1 },
      },
    }
  }
```

## Bonus

Access parrot.nvim directly from your terminal:

```bash
command nvim -c "PrtChatNew"
```

Also works by piping content directly into the chat:

```bash
ls -l | command nvim - -c "normal ggVGy" -c ":PrtChatNew" -c "normal p"
```

## Roadmap

- Add status line integration/ notifications for summary of tokens used or money spent
- Improve the documentation
- Create a tutorial video
- Reduce overall code complexity and improve robustness

## FAQ

- I am encountering errors related to the state.
    > If the state is corrupted, simply delete the file `~/.local/share/nvim/parrot/persisted/state.json`.
- The completion feature is not functioning, and I am receiving errors.
    > Ensure that you have an adequate amount of API credits and examine the log file `~/.local/state/nvim/parrot.nvim.log` for any errors.
- I have discovered a bug, have a feature suggestion, or possess a general idea to enhance this project.
    > Everyone is invited to contribute to this project! If you have any suggestions, ideas, or bug reports, please feel free to submit an issue.

## Related Projects

- [parrot.nvim](https://github.com/frankroeder/parrot.nvim) is a fork of an earlier version of [robitx/gp.nvim](https://github.com/Robitx/gp.nvim)
- [huynle/ogpt.nvim](https://github.com/huynle/ogpt.nvim)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=frankroeder/parrot.nvim&type=Date)](https://star-history.com/#frankroeder/parrot.nvim&Date)
