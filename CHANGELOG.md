# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-09-05

### Added
- Initial release of TabletAuth
- PIN-based authentication system for tablet applications
- User schema with secure PIN hashing using bcrypt
- PIN strength validation (prevents weak/common patterns)
- Account lockout protection after failed attempts
- Device registration for mobile device authentication
- Session management and activity tracking
- Device revocation capabilities
- Comprehensive security features including:
  - Sequential PIN detection
  - Repetitive PIN detection
  - Common weak PIN pattern blocking
- Configurable security parameters:
  - PIN length (default: 4 digits)
  - Maximum failed attempts (default: 3)
  - Lockout duration (default: 15 minutes)
  - Session timeout (default: 60 minutes)
- Complete documentation and usage examples
- MIT license