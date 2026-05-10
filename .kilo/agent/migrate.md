---
name: migrate
description: Assist with breaking changes and migrations
triggers:
  - keyword: /migrate
  - keyword: /upgrade
input:
  - name: migration_type
    type: choice
    options:
      - "config-schema"    # Config structure changes
      - "api-version"      # API version upgrade
      - "database"         # Datastore migration
    prompt: "Migration type"
  - name: from_version
    type: string
    prompt: "From version (e.g., v1.0.0)"
  - name: to_version
    type: string
    prompt: "To version (e.g., v1.1.0)"
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Migration Assistant ==="
      echo "Type: {{migration_type}}"
      echo "From: {{from_version}} → To: {{to_version}}"
      echo ""

      case "{{migration_type}}" in
        "config-schema")
          echo "Configuration Schema Migration"
          echo "--------------------------------"
          echo ""
          echo "1. Check config changes:"
          echo "   git diff {{from_version}}..{{to_version}} -- psiphon/config.go"
          echo ""
          echo "2. Common migration steps:"
          echo "   - Add new fields with defaults"
          echo "   - Maintain backward compatibility"
          echo "   - Deprecate old fields with warnings"
          echo "   - Update LoadConfig to handle both formats"
          echo ""
          echo "3. Migration function template:"
          echo ""
          cat << 'EOF'
      func migrateConfig(oldConfig map[string]interface{}) (map[string]interface{}, error) {
          // Add new fields
          if _, ok := oldConfig["newField"]; !ok {
              oldConfig["newField"] = "defaultValue"
          }

          // Rename fields
          if oldVal, ok := oldConfig["oldField"]; ok {
              oldConfig["newField"] = oldVal
              delete(oldConfig, "oldField")
          }

          return oldConfig, nil
      }
      EOF
          ;;
        "api-version")
          echo "API Version Migration"
          echo "---------------------"
          echo ""
          echo "1. Update API protocol version in:"
          echo "   - psiphon/common/protocol/api.go"
          echo "   - server/api.go"
          echo ""
          echo "2. Maintain backward compatibility:"
          echo "   - Support both old and new versions temporarily"
          echo "   - Use version negotiation in handshake"
          echo ""
          echo "3. Deprecation timeline:"
          echo "   - Phase 1: Support both versions (1-2 releases)"
          echo "   - Phase 2: Log warnings for old version"
          echo "   - Phase 3: Drop old version support"
          ;;
        "database")
          echo "Datastore Migration"
          echo "-------------------"
          echo ""
          echo "BoltDB migration steps:"
          echo "1. Create new bucket/keys with new schema"
          echo "2. Read old data, transform, write new"
          echo "3. Verify counts match"
          echo "4. Optional: remove old bucket"
          echo ""
          echo "Template:"
          cat << 'EOF'
      func migrateDataStore(tx *bolt.Tx) error {
          // Old bucket
          oldBucket := tx.Bucket([]byte("old_bucket"))

          // New bucket
          newBucket, err := tx.CreateBucketIfNotExists([]byte("new_bucket"))
          if err != nil {
              return errors.Trace(err)
          }

          // Iterate and migrate
          cursor := oldBucket.Cursor()
          for k, v := cursor.First(); k != nil; k, v = cursor.Next() {
              newV := transform(v)
              if err := newBucket.Put(k, newV); err != nil {
                  return errors.Trace(err)
              }
          }
          return nil
      }
      EOF
          ;;
      esac

      echo ""
      echo "Migration plan generated. Implement and test thoroughly!"
    description: Generate migration plan
  - type: suggest
    message: |
      Migration guidance prepared.

      Key reminders:
      ✓ Always backup before migrating
      ✓ Test migration on copy of production data
      ✓ Keep old format readable during transition
      ✓ Provide rollback mechanism
      ✓ Update documentation

      Need a specific migration script? Provide more details.
