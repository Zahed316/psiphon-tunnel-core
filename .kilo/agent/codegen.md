---
name: codegen
description: Generate Go code stubs and boilerplate
triggers:
  - keyword: /generate
  - keyword: /codegen
input:
  - name: generation_type
    type: choice
    options:
      - "config-struct"      # New config struct
      - "notice-handler"     # Notice handler function
      - "error-type"         # Custom error type
      - "interface"          # Interface definition
      - "constants"          # Constants block
    prompt: "What to generate"
  - name: name
    type: string
    prompt: "Name for the generated code"
actions:
  - type: suggest
    message: |
      Code generation templates:

      ## 1. Config Struct Template
      ```go
      type {{name}}Config struct {
          Enable bool `json:"enable"`
          Port   int  `json:"port"`
          // Add fields
      }

      func (c *{{name}}Config) Validate() error {
          if c.Port < 0 || c.Port > 65535 {
              return errors.TraceMsg("invalid port: %d", c.Port)
          }
          return nil
      }
      ```

      ## 2. Notice Handler Template
      ```go
      func register{{name}}Notices() {
          psiphon.RegisterNoticeHandler(NoticeType{{name}}, func(data interface{}) {
              // Handle notice
              notice := data.({{name}}NoticeData)
              // Process
          })
      }
      ```

      ## 3. Custom Error Type
      ```go
      type {{name}}Error struct {
          OP   string
          Err  error
      }

      func (e *{{name}}Error) Error() string {
          return fmt.Sprintf("{{name}} %s: %v", e.OP, e.Err)
      }

      func (e *{{name}}Error) Unwrap() error {
          return e.Err
      }
      ```

      ## 4. Interface Template
      ```go
      type {{name}} interface {
          {{if .is_method}}Do{{name}}() error{{else}}Process(data []byte) ([]byte, error){{end}}
      }

      // Ensure compile-time check
      var _ {{name}} = (*{{name}}Impl)(nil)
      ```

      Which template do you need? Ask with `/codegen <template> <name>`
    show_output: false
