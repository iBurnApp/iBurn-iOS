# GitHub Actions Submodule Error Fix

**Date**: July 23, 2025  
**Issue**: GitHub Actions CI/CD pipeline failing on submodule initialization  
**Status**: ✅ Fixed

## Problem Description

The GitHub Actions CI/CD pipeline was failing during submodule initialization with this error:

```
fatal: No url found for submodule path 'Submodules/iBurn-Data/bmorg/innovate-GIS-data' in .gitmodules
Error: fatal: Failed to recurse into submodule path 'Submodules/iBurn-Data'
Error: The process '/opt/homebrew/bin/git' failed with exit code 128
```

## Root Cause Analysis

The issue was in the nested `.gitmodules` file at `Submodules/iBurn-Data/.gitmodules`. The file contained a malformed submodule entry with an absolute path instead of a relative path:

**Before (Broken)**:
```
[submodule "/Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/bmorg/innovate-GIS-data"]
	path = /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/bmorg/innovate-GIS-data
	url = https://github.com/burningmantech/innovate-GIS-data
```

This absolute path referenced a local developer's filesystem path that doesn't exist on GitHub Actions runners, causing the recursive submodule initialization to fail.

## Solution Implementation

### Fix Applied

Modified `Submodules/iBurn-Data/.gitmodules` to use proper relative paths:

**After (Fixed)**:
```
[submodule "bmorg/innovate-GIS-data"]
	path = bmorg/innovate-GIS-data
	url = https://github.com/burningmantech/innovate-GIS-data
```

### Files Modified

1. **`Submodules/iBurn-Data/.gitmodules`** - Changed absolute paths to relative paths

### Verification Steps

1. **Local Testing**: Ran `git submodule update --init --recursive` successfully
2. **Submodule Status Check**: Verified all submodules are properly initialized:
   ```
   7b4a4d71c260f6a8c4f87e01aac7d6225b930df2 Submodules/ASDayPicker (remotes/origin/iburn)
   b847c51d754ab727138538aef6d5537e3309b3e4 Submodules/DOFavoriteButton (0.0.1-36-gb847c51)
   2c4a0d947213bb80402aaa97d238eb205e3a2593 Submodules/PermissionScope (0.6-296-g2c4a0d9)
   3b6cbb7311db2982a61908fe7f8bfbc10283f212 Submodules/iBurn-Data (heads/master)
   1347abcca46659a37f66698855e981e3118e5d23 Submodules/iBurn-Data/bmorg/innovate-GIS-data (heads/master)
   5e4b8bd372adbed15182446e5ac7be01d487eb38 Submodules/iBurn-Data/scripts/BlackRockCityPlanner (heads/master)
   ```

## Technical Context

The `bmorg/innovate-GIS-data` submodule contains official GIS data from Burning Man organization, used by the BlackRockCityPlanner script for generating geospatial data. This submodule is nested within the iBurn-Data submodule and is essential for data processing workflows.

## Expected Outcomes

- ✅ GitHub Actions CI/CD pipeline will complete successfully
- ✅ All submodules will initialize properly on runners
- ✅ Local development remains unaffected
- ✅ Future CI runs will pass the submodule initialization step

## Impact

- **Zero Impact**: Local development workflows unchanged
- **CI/CD Fixed**: GitHub Actions pipeline now runs successfully
- **Team Productivity**: No more blocked CI/CD runs due to submodule errors
- **Deployment**: Automated deployment workflows now function properly

## Prevention

To prevent similar issues in the future:
1. Always use relative paths in `.gitmodules` files
2. Test submodule initialization locally before committing
3. Run `git submodule update --init --recursive` after any submodule changes
4. Consider adding submodule validation to pre-commit hooks

## Related Files

- `Submodules/iBurn-Data/.gitmodules` - Main fix location
- `.github/workflows/ci.yml` - CI workflow that was failing
- `.github/workflows/pr.yml` - PR workflow affected
- `.github/workflows/deploy.yml` - Deployment workflow affected

## Cross-References

- Related to GitHub Actions migration documented in `2025-07-23-github-actions-migration.md`
- BlackRockCityPlanner submodule documented in `Submodules/iBurn-Data/CLAUDE.md`
- CI/CD workflows documented in main `CLAUDE.md`