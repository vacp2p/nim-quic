## Include this file to indicate that your module does not raise Errors.
## Disables compiler hints about unused declarations.

{.push raises: [Defect].} # only defects are allowed
{.push hint[XDeclaredButNotUsed]: off.} # disable hints that Defect is not used
