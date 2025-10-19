# Security Improvements for File Upload Handling

## Summary of Changes

### 🔒 **Security Vulnerabilities Fixed**

#### 1. **Path Traversal Prevention**
**Before:**
```ruby
temppath_of_export = "tmp/stravaexport_#{random}/#{export_file[:filename].gsub('.zip', '')}"
```
- Used unsanitized user-provided filename
- Vulnerable to path traversal attacks (e.g., `../../etc/passwd.zip`)

**After:**
```ruby
safe_dir_name = "upload_#{strava_id}"
temppath_base = "tmp/stravaexport_#{random}"
temppath_of_export = "#{temppath_base}/#{safe_dir_name}"
```
- Uses controlled naming with validated `strava_id`
- No user input in path construction

#### 2. **Command Injection Prevention**
**Before:**
```ruby
`mkdir tmp/stravaexport_#{random}`
`mkdir tmp/stravaexport_#{random}/#{export_file[:filename].gsub('.zip', '')}`
`unzip #{export_file[:tempfile].path} -d #{temppath_of_export}`
`cp strava-export-organizer #{temppath_of_export}/strava-export-organizer`
`cd #{temppath_of_export} && ./strava-export-organizer #{language}`
`rm #{zipfile_name}`
`rm -rf tmp/stravaexport_#{random}`
```
- Used shell backticks with interpolated variables
- Vulnerable to command injection via filename manipulation

**After:**
```ruby
FileUtils.mkdir_p(temppath_of_export)
system('unzip', '-q', export_file[:tempfile].path, '-d', temppath_of_export)
FileUtils.cp('strava-export-organizer', "#{temppath_of_export}/strava-export-organizer")
Dir.chdir(temppath_of_export) { system('./strava-export-organizer', language) }
FileUtils.rm_f(zipfile_name)
FileUtils.rm_rf(temppath_base)
```
- Uses `FileUtils` methods (no shell interpolation)
- Uses `system()` with array arguments (proper argument separation)
- No shell metacharacter interpretation

#### 3. **Cleanup Command Safety**
**Before:**
```ruby
`find /tmp -name 'RackMultipart.*' -type f -mmin +59 -delete > /dev/null`
```

**After:**
```ruby
system('find', '/tmp', '-name', 'RackMultipart.*', '-type', 'f', '-mmin', '+59', '-delete',
       out: File::NULL, err: File::NULL)
```
- Proper argument separation
- No shell interpretation

## Benefits

### ✅ **Security**
- **Eliminates path traversal attacks**
- **Prevents command injection**
- **No shell metacharacter exploitation**

### ✅ **Code Quality**
- **More idiomatic Ruby** (FileUtils vs shell commands)
- **Better error handling** (Ruby methods raise exceptions)
- **More testable code**

### ✅ **Maintainability**
- **Clearer intent** (FileUtils.mkdir_p vs `mkdir`)
- **Platform independence** (FileUtils works across OS)
- **Easier to debug**

## Testing Recommendations

### Test Cases to Verify Security:

1. **Path Traversal Attempt:**
   - Upload file named: `../../etc/passwd.zip`
   - Expected: Should be safely contained in temp directory

2. **Command Injection Attempt:**
   - Upload file named: `test; rm -rf /; echo pwned.zip`
   - Expected: Should not execute injected commands

3. **Special Characters:**
   - Upload file with: spaces, quotes, backticks, $(), etc.
   - Expected: Should handle gracefully without shell interpretation

4. **Normal Operation:**
   - Upload valid Strava export: `activity_export_123456.zip`
   - Expected: Works as before

## Migration Notes

- No database changes required
- No API changes (user-facing behavior unchanged)
- File paths are now more predictable: `upload_{strava_id}` instead of user filename
- This is a breaking change for any code that depends on the exact temp directory structure

## Deployment

1. Deploy the updated code
2. No special migration steps needed
3. Monitor logs for any issues with file processing
4. Test with sample uploads to verify functionality

---

**Date:** October 19, 2025
**Branch:** clamav-virus-scan
**Related to:** ClamAV integration and security hardening
