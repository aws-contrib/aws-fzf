# Changelog

## [0.3.2](https://github.com/aws-contrib/aws-fzf/compare/v0.3.1...v0.3.2) (2026-02-28)


### Bug Fixes

* add default value syntax to indirect variable expansion ([499c9c8](https://github.com/aws-contrib/aws-fzf/commit/499c9c87b1ec7418dfe4b5377be519d091ead6d0))

## [0.3.1](https://github.com/aws-contrib/aws-fzf/compare/v0.3.0...v0.3.1) (2026-02-27)


### Bug Fixes

* revert read -ra to eval for proper quote handling in fzf options ([46e3b9c](https://github.com/aws-contrib/aws-fzf/commit/46e3b9c530fdf0df3ba4c9914732cf3f0671cf1a))

## [0.3.0](https://github.com/aws-contrib/aws-fzf/compare/v0.2.0...v0.3.0) (2026-02-27)


### Features

* add region parameter to aws sso console url ([26947c6](https://github.com/aws-contrib/aws-fzf/commit/26947c6f8bf3c00275cc11018e21d970f2198da9))
* add type field to sso profile list output ([7646b9c](https://github.com/aws-contrib/aws-fzf/commit/7646b9c96c6f2396345f6e9aa5f45a44ef7a0516))
* replace sso_url with name field in sso profile list ([5e47649](https://github.com/aws-contrib/aws-fzf/commit/5e47649bd65f964e23aadd9cd0053688bdee0ad0))


### Bug Fixes

* add source guard and fix FZF_AWS_FLAGS parsing ([aa438bb](https://github.com/aws-contrib/aws-fzf/commit/aa438bb3b06fd00505e7982a6cfc4f593190e8c7))
* correct aws sso region parameter name ([27f645f](https://github.com/aws-contrib/aws-fzf/commit/27f645fdd407831be9a8f25b56e943b8a2b63d9d))
* make ctrl-o binding abort fzf after opening console ([9df0f63](https://github.com/aws-contrib/aws-fzf/commit/9df0f63af4c2547dd0b2a2874df5045aae3f533f))
* properly escape and parse FZF_AWS_FLAGS environment variable ([676f361](https://github.com/aws-contrib/aws-fzf/commit/676f3618badcf8f95074c6d93f34397b23bc28f5))
* replace "NONE" with "N/A" for consistency in aws_sso.awk ([0fe8faf](https://github.com/aws-contrib/aws-fzf/commit/0fe8fafece9ba9b8ce8ffdbbffb7f3dbbbc524dd))
* replace read builtin with eval for robust flag parsing ([c125760](https://github.com/aws-contrib/aws-fzf/commit/c12576033717372fc2b147169f769d93c21ae00d))
* resolve help)/--help) conflict in cmd files ([29927d8](https://github.com/aws-contrib/aws-fzf/commit/29927d863821223f0fa66004044bbc897088071b))
* separate FZF_AWS_FLAGS declaration from assignment ([36879ee](https://github.com/aws-contrib/aws-fzf/commit/36879eeb4fa8b8baf1deb176702212a974970912))

## [0.2.0](https://github.com/aws-contrib/aws-fzf/compare/v0.1.0...v0.2.0) (2026-02-25)


### Features

* add dependency check, version flag, and improve error handling ([903b39c](https://github.com/aws-contrib/aws-fzf/commit/903b39c10e835d9abfba88988eab5cdafe57134f))
* **aws_log_cmd:** enhance log tailing with pager and exec support ([722954a](https://github.com/aws-contrib/aws-fzf/commit/722954a68e1cc4b42f71308975e14988279910de))
* **aws:** add SSO profile support to aws-fzf ([76ca3f3](https://github.com/aws-contrib/aws-fzf/commit/76ca3f3ff5a1a5ddc00b6d28c0b6ad0694f85a82))
* **cli,docs:** change parameter/secret value retrieval to clipboard copy ([fa4fcfb](https://github.com/aws-contrib/aws-fzf/commit/fa4fcfb5161a104bb1c7b5ba4ccfe3811678906d))
* **cli:** add dynamic fzf flags support for aws-fzf ([9673e35](https://github.com/aws-contrib/aws-fzf/commit/9673e35db83d8cd5957a965afb0087cf797b87c6))
* **cli:** add resource identifier copy and enhanced troubleshooting ([1de77ad](https://github.com/aws-contrib/aws-fzf/commit/1de77ad80c535fa590648fc10c83ece40a0b7637))
* **cli:** enhance log history duration parsing ([15721c0](https://github.com/aws-contrib/aws-fzf/commit/15721c04693b278cf944c3ae5eb1b6a6cd747ead))
* **cli:** simplify aws log tailing command ([52d3912](https://github.com/aws-contrib/aws-fzf/commit/52d3912b7814c44bbb8fab91f86fb11539f6d039))
* **dsql:** add interactive DSQL cluster browsing ([900b6b5](https://github.com/aws-contrib/aws-fzf/commit/900b6b5f958c857fb834c6ddc7c4323dfb2eff36))
* **dynamodb:** add interactive DynamoDB table browsing ([679f59c](https://github.com/aws-contrib/aws-fzf/commit/679f59ca1421b609b0087223149a11e5eff53394))
* **fzf:** add interactive help preview for various AWS services ([a3ad2cf](https://github.com/aws-contrib/aws-fzf/commit/a3ad2cf1f256cee83e2e1ffc385dc2a1058cd5d2))
* **fzf:** add per-command fzf configuration options ([81e88fc](https://github.com/aws-contrib/aws-fzf/commit/81e88fc0e5302c8749b145c68cf71afe48106bd6))
* Initial commit of aws-fzf ([f398972](https://github.com/aws-contrib/aws-fzf/commit/f3989727427b1d3b79bac9384c52273d114bd955))
* **rds:** add interactive PostgreSQL database connection with IAM auth ([923d82b](https://github.com/aws-contrib/aws-fzf/commit/923d82b73706f791e79abcbd9229e680f7e82116))
* **rds:** add interactive RDS database browsing ([d5a284a](https://github.com/aws-contrib/aws-fzf/commit/d5a284aa849b274d74edb7e638e685c838c2e102))
* **s3:** add configurable S3 bucket viewer via environment variable ([cf487b6](https://github.com/aws-contrib/aws-fzf/commit/cf487b6cee6278dd72206ca4951ecf48ecc91c54))
* **sso:** add SSO profile browsing and authentication ([76ead26](https://github.com/aws-contrib/aws-fzf/commit/76ead260603ffd0af38279bd0b2e664340b5043d))


### Bug Fixes

* **aws-sso:** change logout keyboard shortcut from alt-l to alt-x ([fe2b11d](https://github.com/aws-contrib/aws-fzf/commit/fe2b11db4d5772636f28d7ab90435b08955f26b8))
* **aws:** use gum pager instead of abort for output display ([af8e498](https://github.com/aws-contrib/aws-fzf/commit/af8e498772b0384f20630051f1ca9e1327295f2c))
* clean up remaining minor tech debt ([8a64206](https://github.com/aws-contrib/aws-fzf/commit/8a64206fe51d9fc2d47b47112ab4e7c24a938460))
* resolve tech debt, stale docs, and service name mismatch ([6d97b8b](https://github.com/aws-contrib/aws-fzf/commit/6d97b8bb55ac336f1a83433134ef9faa4f442a9d))
* use user-facing command names in help text and error messages ([9ddaf2d](https://github.com/aws-contrib/aws-fzf/commit/9ddaf2d8b46e93d5869b696371ce88ab688ae9a5))
