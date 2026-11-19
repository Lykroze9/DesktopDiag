@{
    Severity     = @('Error', 'Warning')
    # Rules that do not fit read-only collection scripts (no state change, deliberate empty catches
    # around optional data sources, fixtures named New-* that only build objects).
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUseSingularNouns',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseBOMForUnicodeEncodedFile'
    )
}
