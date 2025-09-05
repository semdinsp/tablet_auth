# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2025-09-05

### Security
- **CRITICAL**: Fixed timing attack vulnerability in `User.verify_pin/2` - now runs in constant time even with nil users
- Improved PIN generation using crypto-secure randomness (`crypto.strong_rand_bytes`) instead of `rand.uniform`
- Redacted PINs from all log messages to prevent secrets leaking into log files

### Added
- Additional test coverage for timing attack protection
- Security-conscious logging with PIN redaction

### Fixed
- Timing attack protection in PIN verification
- Removed potential PIN disclosure in logs
- Improved cryptographic randomness in PIN generation

## [0.1.2] - 2025-09-05

### Added
- Display-based tablet registration system with PIN expiration
- Enhanced secret key generation using 256-bit entropy
- Display-based tablet registration functionality
- PIN validation and expiration for display registration
- Secret key based tablet authentication
- Comprehensive logging framework

## [0.1.1] - 2025-09-05

### Added
- Display-based registration system
- Enhanced tablet authentication workflows

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