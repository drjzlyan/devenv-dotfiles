#!/usr/bin/env bash
set -euo pipefail

# Scaffold a new project for a given language.
#
# Usage:
#   project-init.sh <language> <name> [parent_dir]
#
# Examples:
#   project-init.sh python myapp
#   project-init.sh java com.example.myapp
#   project-init.sh typescript myapp
#   project-init.sh go github.com/user/myapp
#   project-init.sh cpp myapp
#   project-init.sh rust myapp
#
# Creates the project directory, initializes files, and runs git init.
# If inside a tmux session, opens the project in a new dev window.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGES_FILE="${LANGUAGES_FILE:-$HOME/.local/share/nvim/languages.local}"

log() {
  printf '[init] %s\n' "$*"
}

has_language() {
  [[ -f "$LANGUAGES_FILE" ]] && grep -qE "^${1}=" "$LANGUAGES_FILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Language scaffolds
# ---------------------------------------------------------------------------

init_python() {
  local name="$1"
  local dir="$2"

  if command -v uv >/dev/null 2>&1; then
    log "Using uv to scaffold Python project..."
    (cd "$dir" && uv init --name "$name" 2>/dev/null || true)
  fi

  cat > "$dir/pyproject.toml" <<EOF
[project]
name = "$name"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = []

[dependency-groups]
dev = [
    "pytest>=8.0",
    "ruff>=0.6",
]
EOF

  mkdir -p "$dir/src/$name" "$dir/tests"
  touch "$dir/src/$name/__init__.py"

  cat > "$dir/src/$name/main.py" <<EOF
def main() -> None:
    print("Hello from $name!")


if __name__ == "__main__":
    main()
EOF

  cat > "$dir/tests/test_main.py" <<EOF
from $name.main import main


def test_main(capsys):
    main()
    captured = capsys.readouterr()
    assert "Hello from $name!" in captured.out
EOF

  cat > "$dir/.gitignore" <<EOF
__pycache__/
*.pyc
.venv/
*.egg-info/
dist/
.pytest_cache/
.mypy_cache/
.ruff_cache/
EOF

  log "Python project '$name' created in $dir"
}

init_java() {
  local name="$1"
  local dir="$2"
  local group_id="$3"

  local pkg_path
  pkg_path=$(echo "$group_id" | tr '.' '/')
  local pkg_dir="$dir/src/main/java/$pkg_path"
  local test_dir="$dir/src/test/java/$pkg_path"

  mkdir -p "$pkg_dir" "$test_dir"

  local class_name
  class_name=$(echo "$basename" | sed 's/[^a-zA-Z0-9]//g')
  class_name="$(echo "${class_name:0:1}" | tr '[:lower:]' '[:upper:]')${class_name:1}"
  [[ -z "$class_name" ]] && class_name="App"

  cat > "$dir/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>$group_id</groupId>
    <artifactId>$name</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.10.0</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.2.0</version>
            </plugin>
        </plugins>
    </build>
</project>
EOF

  cat > "$pkg_dir/$class_name.java" <<EOF
package $group_id;

public class $class_name {
    public static void main(String[] args) {
        System.out.println("Hello from $name!");
    }
}
EOF

  cat > "$test_dir/${class_name}Test.java" <<EOF
package $group_id;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ${class_name}Test {
    @Test
    void mainRuns() {
        assertDoesNotThrow(() -> $class_name.main(null));
    }
}
EOF

  cat > "$dir/.gitignore" <<EOF
target/
*.class
.idea/
*.iml
.classpath
.project
.settings/
EOF

  log "Java project '$name' created in $dir"
}

init_typescript() {
  local name="$1"
  local dir="$2"

  mkdir -p "$dir/src" "$dir/test"

  cat > "$dir/package.json" <<EOF
{
  "name": "$name",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "node --test dist/test/"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "@types/node": "^22.0.0"
  }
}
EOF

  cat > "$dir/tsconfig.json" <<EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": ".",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src", "test"]
}
EOF

  cat > "$dir/src/index.ts" <<EOF
export function main(): void {
  console.log("Hello from $name!");
}

main();
EOF

  cat > "$dir/test/index.test.ts" <<EOF
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { main } from "../src/index.js";

describe("main", () => {
  it("should not throw", () => {
    assert.doesNotThrow(() => main());
  });
});
EOF

  cat > "$dir/.gitignore" <<EOF
node_modules/
dist/
*.js
*.d.ts
!jest.config.js
EOF

  if command -v npm >/dev/null 2>&1; then
    log "Installing npm dependencies..."
    (cd "$dir" && npm install 2>/dev/null || true)
  fi

  log "TypeScript project '$name' created in $dir"
}

init_go() {
  local module="$1"
  local dir="$2"
  local app_name
  app_name=$(echo "$module" | tr '/.' '\n\n' | tail -1)

  mkdir -p "$dir/cmd/$app_name"

  if command -v go >/dev/null 2>&1; then
    (cd "$dir" && go mod init "$module" 2>/dev/null || true)
  else
    cat > "$dir/go.mod" <<EOF
module $module

go 1.23
EOF
  fi

  cat > "$dir/cmd/$app_name/main.go" <<EOF
package main

import "fmt"

func main() {
	fmt.Println("Hello from $module!")
}
EOF

  cat > "$dir/.gitignore" <<EOF
/bin/
*.exe
*.test
*.out
dist/
EOF

  log "Go project '$module' created in $dir"
}

init_cpp() {
  local name="$1"
  local dir="$2"

  mkdir -p "$dir/src" "$dir/tests"

  cat > "$dir/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.20)
project($name CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable($name src/main.cpp)

enable_testing()
add_executable(test_main tests/test_main.cpp)
target_link_libraries(test_main PRIVATE $name)
add_test(NAME main_test COMMAND test_main)
EOF

  cat > "$dir/src/main.cpp" <<EOF
#include <iostream>

int main() {
    std::cout << "Hello from $name!" << std::endl;
    return 0;
}
EOF

  cat > "$dir/tests/test_main.cpp" <<EOF
#include <cassert>
#include <iostream>

int main() {
    // Add tests here
    assert(true);
    std::cout << "All tests passed!" << std::endl;
    return 0;
}
EOF

  cat > "$dir/.gitignore" <<EOF
build/
*.o
*.out
*.exe
compile_commands.json
.cache/
EOF

  log "C/C++ project '$name' created in $dir"
}

init_rust() {
  local name="$1"
  local dir="$2"

  if command -v cargo >/dev/null 2>&1; then
    log "Using cargo to scaffold Rust project..."
    cargo init "$dir" --name "$name" 2>/dev/null || true
  else
    mkdir -p "$dir/src"
    cat > "$dir/Cargo.toml" <<EOF
[package]
name = "$name"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF

    cat > "$dir/src/main.rs" <<EOF
fn main() {
    println!("Hello from $name!");
}
EOF
  fi

  # Ensure .gitignore exists
  if [[ ! -f "$dir/.gitignore" ]]; then
    cat > "$dir/.gitignore" <<EOF
/target/
*.rs.bk
EOF
  fi

  log "Rust project '$name' created in $dir"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: project-init.sh <language> <name> [parent_dir]

Languages: python, java, typescript, go, cpp, rust

Examples:
  project-init.sh python myapp
  project-init.sh java com.example.myapp
  project-init.sh typescript myapp
  project-init.sh go github.com/user/myapp
  project-init.sh cpp myapp
  project-init.sh rust myapp

The project is created in <parent_dir>/<basename> or ./<basename> by default.
EOF
  exit 1
}

main() {
  local lang="${1:-}"
  local name="${2:-}"
  local parent_dir="${3:-.}"

  [[ -z "$lang" || -z "$name" ]] && usage

  # Derive directory name from the last path component
  local basename
  basename=$(echo "$name" | tr '/.' '\n\n' | tail -1)
  [[ -z "$basename" ]] && basename="$name"

  local dir
  dir="$parent_dir/$basename"

  if [[ -e "$dir" ]]; then
    log "Error: $dir already exists"
    exit 1
  fi

  mkdir -p "$dir"

  case "$lang" in
    python)
      init_python "$basename" "$dir"
      ;;
    java)
      local group_id="$name"
      init_java "$basename" "$dir" "$group_id"
      ;;
    typescript|ts|node)
      init_typescript "$basename" "$dir"
      ;;
    go|golang)
      init_go "$name" "$dir"
      ;;
    cpp|c|c++)
      init_cpp "$basename" "$dir"
      ;;
    rust|rs)
      init_rust "$basename" "$dir"
      ;;
    *)
      log "Unknown language: $lang"
      log "Supported: python, java, typescript, go, cpp, rust"
      exit 1
      ;;
  esac

  # Git init
  if command -v git >/dev/null 2>&1; then
    (cd "$dir" && git init 2>/dev/null && git add -A && git commit -m "Initial commit" 2>/dev/null) || true
    log "Git initialized"
  fi

  log ""
  log "Project created: $dir"
  log "  cd $dir && dev"
}

main "$@"
