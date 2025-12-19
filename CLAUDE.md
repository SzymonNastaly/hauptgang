# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Learning Project

**IMPORTANT**: This is first and foremost a learning project. The developer has a programming background but has never developed a Ruby on Rails project and wants to learn Rails properly.

When assisting with this project:
- **Explain** what you're doing and why, rather than just doing it
- **Teach** Rails conventions, patterns, and best practices
- **Guide** the developer to write code themselves when possible
- **Suggest** approaches and let the developer implement them
- **Ask** if the developer wants to try implementing something before doing it for them
- Only write complete implementations when explicitly requested or for boilerplate/setup tasks

The goal is learning and understanding, not just getting features built quickly.

## Project Overview

RecipeTracker is a Rails 8.1 application using Ruby 3.4.7. It follows Rails conventions and uses modern Rails features including Hotwire (Turbo and Stimulus), SQLite databases, and the Solid suite (Solid Cache, Solid Queue, Solid Cable) for caching, background jobs, and Action Cable.

## Development Commands

### Initial Setup
```bash
bin/setup                    # Install dependencies, prepare database, start server
bin/setup --skip-server     # Setup without starting server
bin/setup --reset           # Reset database during setup
```

### Running the Application
```bash
bin/dev                     # Start development server (Rails server)
bin/rails server            # Alternative way to start server
```

### Database Operations
```bash
bin/rails db:prepare        # Create and migrate database
bin/rails db:migrate        # Run pending migrations
bin/rails db:rollback       # Rollback last migration
bin/rails db:seed           # Load seed data
bin/rails db:reset          # Drop, create, migrate, and seed database
bin/rails dbconsole         # Open database console
```

### Testing
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests only
bin/rails test test/models/your_model_test.rb  # Run a single test file
bin/rails test test/models/your_model_test.rb:10  # Run test at specific line
```

### Code Quality & Security
```bash
bin/rubocop                 # Run Ruby style checker (Omakase Ruby styling)
bin/rubocop -a              # Auto-fix safe offenses
bin/brakeman                # Run security code analysis
bin/bundler-audit           # Audit gems for security vulnerabilities
bin/importmap audit         # Audit importmap dependencies
bin/ci                      # Run full CI suite (setup, style, security, tests)
```

### Asset Management
```bash
bin/importmap               # Manage JavaScript dependencies via importmap
bin/rails assets:precompile # Precompile assets for production
```

### Deployment (Kamal)
```bash
bin/kamal console           # Open Rails console on deployed server
bin/kamal shell             # SSH into deployed container
bin/kamal logs              # Tail application logs
bin/kamal dbc               # Open database console on deployed server
```

## Architecture

### Database Configuration
- **Development/Test**: SQLite3 databases in `storage/` directory
- **Production**: Multi-database setup with separate SQLite databases for:
  - `primary`: Main application data
  - `cache`: Solid Cache storage (migrations in `db/cache_migrate`)
  - `queue`: Solid Queue storage (migrations in `db/queue_migrate`)
  - `cable`: Solid Cable storage (migrations in `db/cable_migrate`)

### Background Jobs
- Uses **Solid Queue** for background job processing
- In production, `SOLID_QUEUE_IN_PUMA=true` runs queue supervisor inside Puma process
- For multi-server setups, dedicated job servers should be configured

### Caching
- Uses **Solid Cache** for database-backed caching in production
- Configuration in `config/cache.yml`

### Real-time Features
- Uses **Solid Cable** for Action Cable WebSocket connections
- Database-backed adapter for production

### Frontend Stack
- **Tailwind CSS v4** via `tailwindcss-rails` gem (media query-based dark mode)
- **SVG icon partials** in `app/views/icons/` (no external icon library)
- **Importmap** for JavaScript dependencies (no Node.js/npm required)
- **Turbo** for SPA-like page navigation
- **Stimulus** for JavaScript behavior
- **Propshaft** for asset pipeline
- Assets served from `app/assets` and `app/javascript`

### Deployment
- Configured for **Kamal** deployment
- Docker-based deployment with Thruster as the HTTP server
- Deployment config in `config/deploy.yml`
- Server configured at `192.168.0.1` (update for your environment)
- Persistent storage volume: `recipetracker_storage:/rails/storage`

## Code Style

This project uses **rubocop-rails-omakase** for Ruby styling, which provides standardized Rails conventions from Basecamp/37signals. Follow these standards when writing code.

## CI Pipeline

The CI pipeline (`bin/ci`) runs:
1. Setup (dependencies and database)
2. Ruby style checks (RuboCop)
3. Security audits (bundler-audit, importmap audit, Brakeman)
4. Rails unit/integration tests
5. System tests
6. Database seed validation

All checks must pass before merging.

## Key Files

- `config/application.rb`: Main application configuration (module: `Recipetracker`)
- `config/routes.rb`: Route definitions
- `config/database.yml`: Multi-database configuration
- `config/deploy.yml`: Kamal deployment settings
- `Dockerfile`: Production container image definition
- `.rubocop.yml`: Ruby style configuration
