#@section NULL
# virtual module that pulls in functions/modules for standard scripts


#@section functions_export

## functions from die

# @extern @noreturn die ( [message], [code] )


## functions from autodie

# @extern void autodie ( *cmdv )


## functions from function_die

# @extern @noreturn function_die ( [message], [function_name], [code] )


## functions from message

# @extern void einfo    ( message, [header] )
# @extern void ewarn    ( message, [header] )
# @extern void eerror   ( message, [header] )
# @extern void veinfo   ( message, [header] )
# @extern void printvar ( *varname, **F_PRINTVAR=einfo )
# @extern void message  ( message )
