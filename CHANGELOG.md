# Changelog

## [1.2.3](https://github.com/frankroeder/parrot.nvim/compare/v1.2.2...v1.2.3) (2025-02-05)


### Bug Fixes

* **perplexity:** add new reasoning model ([7a87bab](https://github.com/frankroeder/parrot.nvim/commit/7a87bab9d9d37d00ff244bcd56cd1a9739692e30))

## [1.2.2](https://github.com/frankroeder/parrot.nvim/compare/v1.2.1...v1.2.2) (2025-01-26)


### Bug Fixes

* add missing module in mistral provider ([b8f52da](https://github.com/frankroeder/parrot.nvim/commit/b8f52dab988a2c21d18aff3ba7806ddc36c2fe8d))
* change current_provider default value to nil ([a8468be](https://github.com/frankroeder/parrot.nvim/commit/a8468be7311ac04b86bf08a05ea480f444b7c1ea))
* **perplexity:** update available models ([bdb30c2](https://github.com/frankroeder/parrot.nvim/commit/bdb30c2007f523e97911185ec97a55486adbecab))

## [1.2.1](https://github.com/frankroeder/parrot.nvim/compare/v1.2.0...v1.2.1) (2024-11-19)


### Bug Fixes

* Set filetype to markdown for parrot responses ([119828b](https://github.com/frankroeder/parrot.nvim/commit/119828b016c07c547a093fb31bf60272d518e033))
* use literal string compare before file deletion ([4d43901](https://github.com/frankroeder/parrot.nvim/commit/4d439010e6abf7bcb3e70761a3ccadaed19135ad))
* xAI API change of model listing request ([c992483](https://github.com/frankroeder/parrot.nvim/commit/c992483dd0cf9d7481b55714d52365d1f7a66f91))

## [1.2.0](https://github.com/frankroeder/parrot.nvim/compare/v1.1.0...v1.2.0) (2024-10-21)


### Features

* add xAI as provider for Grok ([ef0149d](https://github.com/frankroeder/parrot.nvim/commit/ef0149d4b335d83d79deacae2f4bbf10e78314f5))

## [1.1.0](https://github.com/frankroeder/parrot.nvim/compare/v1.0.0...v1.1.0) (2024-10-17)


### Features

* add nvidia api support ([94e218d](https://github.com/frankroeder/parrot.nvim/commit/94e218dee56344d065c9d0cf37d89225d03ae5f5))


### Bug Fixes

* resolve issue with toggle_target ([51e7d1c](https://github.com/frankroeder/parrot.nvim/commit/51e7d1c2820fb4333bdcfc9751abfa74e9d90329))

## [1.0.0](https://github.com/frankroeder/parrot.nvim/compare/v0.7.0...v1.0.0) (2024-10-15)


### ⚠ BREAKING CHANGES

* ChatNew now follows toggle_target option

### Features

* ChatNew now follows toggle_target option ([345fb4e](https://github.com/frankroeder/parrot.nvim/commit/345fb4e3bed17c1822c1cd40ccec158be13d3f7e))


### Bug Fixes

* **ollama:** additional guard if server is not running ([fdcaa6c](https://github.com/frankroeder/parrot.nvim/commit/fdcaa6ccc368b69f0b0cdd8d5998e53ac2812aeb))
* **provider:** remove pplx event-stream header ([b347a1c](https://github.com/frankroeder/parrot.nvim/commit/b347a1ce80336a519634df3668c8b940acf83653))
* resolve history bug with custom hooks ([0db1e3b](https://github.com/frankroeder/parrot.nvim/commit/0db1e3beff0c434fec13c809bd105a4485946ece))

## [0.7.0](https://github.com/frankroeder/parrot.nvim/compare/v0.6.0...v0.7.0) (2024-09-11)


### Features

* add github model beta support ([6f36955](https://github.com/frankroeder/parrot.nvim/commit/6f36955a2174af95c3cf98165e907cdf60f289bb))
* **provider:** add gemini online model support ([be975ee](https://github.com/frankroeder/parrot.nvim/commit/be975ee542c8c24ebb90f154e25e2c89633b5d2d))


### Bug Fixes

* add missing import ([4a50b58](https://github.com/frankroeder/parrot.nvim/commit/4a50b58ce0036009ffc7419df2c2619e8a09496e))
* **responsehandler:** address bug ([075294c](https://github.com/frankroeder/parrot.nvim/commit/075294c1a9da6e35727007c4105590b8768d3681))
* **responsehandler:** window handling ([f2cbfc5](https://github.com/frankroeder/parrot.nvim/commit/f2cbfc592e1a5c470a840abdba5abc4940911f55))

## [0.6.0](https://github.com/frankroeder/parrot.nvim/compare/v0.5.0...v0.6.0) (2024-08-22)


### Features

* add status line support ([3ac1d28](https://github.com/frankroeder/parrot.nvim/commit/3ac1d2885428a573b4851bbc07735465a2019351))
* **commands:** implement the retry command ([29f7701](https://github.com/frankroeder/parrot.nvim/commit/29f7701585e02abc363df0691c37f6699494bd03))


### Bug Fixes

* add `PrtStatus` command ([322a45e](https://github.com/frankroeder/parrot.nvim/commit/322a45ead223c4698f52ba5d03e745fe330a7ab5))
* add missing multifilecontent support for chat prompts ([b8f221e](https://github.com/frankroeder/parrot.nvim/commit/b8f221efdde7c0294917ecb96829e1e1fe6986b2))
* Neovim version check ([a4fd3f3](https://github.com/frankroeder/parrot.nvim/commit/a4fd3f3a55a258c689cd97f0b85a0f267bc239e3))
* revert wrong license change ([1a7192c](https://github.com/frankroeder/parrot.nvim/commit/1a7192c3842f55578f787ff08766d7d4e713f701))

## [0.5.0](https://github.com/frankroeder/parrot.nvim/compare/v0.4.2...v0.5.0) (2024-08-14)


### Features

* add option to toggle online model selection ([3f74c06](https://github.com/frankroeder/parrot.nvim/commit/3f74c06743ccbe200067892022fd84b908f3bce5))


### Bug Fixes

* add missing arguments to release-please ([70e7b06](https://github.com/frankroeder/parrot.nvim/commit/70e7b06cd9dc0fcf5cb6214402a5dd1bacf26661))
* extend permission of release worflow ([df22467](https://github.com/frankroeder/parrot.nvim/commit/df224670e5ee3e3a5c38e5de189112588455db11))
* typo ([edec3b1](https://github.com/frankroeder/parrot.nvim/commit/edec3b1740eac16fa3853fe2fb0d22c9f8095870))
* update pipeline ([917c102](https://github.com/frankroeder/parrot.nvim/commit/917c10276d5ce6ef1e93907e64b78003fb176eee))
* user_input_ui now supports the "buffer" option ([22abeb3](https://github.com/frankroeder/parrot.nvim/commit/22abeb3378b6c978a8fd7629a755e1af44d3f40c))
