---
name: test-gen
description: Generate unit test scaffolding for new functions/structures
triggers:
  - keyword: /gen-test
  - keyword: /test-scaffold
input:
  - name: package_name
    type: string
    prompt: "Package name (e.g., obfuscator, protocol)"
  - name: function_name
    type: string
    prompt: "Function/type name to test"
  - name: test_type
    type: choice
    options:
      - "unit"     # Single function test
      - "table"    # Table-driven test
      - "benchmark" # Benchmark
      - "integration" # Integration test
    prompt: "Test type"
actions:
  - type: create_file
    path: "psiphon/common/{{package_name}}/{{function_name|lower}}_test.go"
    template: |
      package {{package_name}}

      import (
          "testing"
          "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common/errors"
          {{if eq .test_type "benchmark"}}"time"{{end}}
      )

      {{if eq .test_type "table"}}
      var testCases = []struct {
          name     string
          input    interface{}
          expected interface{}
          wantErr  bool
      }{
          {
              name:     "basic case",
              input:    nil,
              expected: nil,
              wantErr:  false,
          },
      }
      {{end}}

      {{if eq .test_type "unit"}}
      // Test{{function_name}} tests {{function_name}} behavior.
      func Test{{function_name}}(t *testing.T) {
          t.Parallel()

          // TODO: Add test cases
          // Arrange
          // Act
          // Assert
      }
      {{end}}

      {{if eq .test_type "table"}}
      // Test{{function_name}} tests {{function_name}} with table-driven cases.
      func Test{{function_name}}(t *testing.T) {
          t.Parallel()

          for _, tc := range testCases {
              t.Run(tc.name, func(t *testing.T) {
                  t.Parallel()

                  // Act
                  got, err := {{function_name}}(tc.input)

                  // Assert
                  if tc.wantErr {
                      if err == nil {
                          t.Fatal("want error, got nil")
                      }
                      return
                  }

                  if err != nil {
                      t.Fatalf("unexpected error: %v", err)
                  }

                  // Add proper equality check for your types
                  // if !reflect.DeepEqual(got, tc.expected) {
                  //     t.Errorf("got %v, want %v", got, tc.expected)
                  // }
              })
          }
      }
      {{end}}

      {{if eq .test_type "benchmark"}}
      // Benchmark{{function_name}} benchmarks {{function_name}}.
      func Benchmark{{function_name}}(b *testing.B) {
          for i := 0; i < b.N; i++ {
              // Call function to benchmark
          }
      }
      {{end}}

      {{if eq .test_type "integration"}}
      // Test{{function_name}}Integration tests {{function_name}} with real components.
      func Test{{function_name}}Integration(t *testing.T) {
          // Skip if test-only config
          if testing.Short() {
              t.Skip("skipping integration test in short mode")
          }

          // Setup test environment
          // Create real instances
          // Verify end-to-end behavior
      }
      {{end}}

  - type: suggest
    message: |
      Test scaffold generated for {{function_name}}!

      Next steps:
      1. Fill in TODO sections with actual test logic
      2. Add test data in `testdata/` directory if needed
      3. Run: go test -v ./psiphon/common/{{package_name}}/
      4. Add table test cases if using table-driven pattern

      Pro tips:
      - Use t.Parallel() for independent sub-tests
      - Use errors.Trace() in assertions for better diagnostics
      - Check testdata/ for existing fixtures you can reuse
