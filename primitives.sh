### yoda base vocabulary ###

# ----- populating detokeniser -------------- #fold00
# for testing, a handful of inlined single operation primitives
# and atomic operations are added. no optimising take place now.
# atoms are only substituted against corresponding code.
# atoms are tagged as such in the source, some correspond to
# names of primitives. This is meant for having the optimiser
# hooked into code generation, for doing some more substantial
# work later on. chosing these operations allows tracking of
# recent use of stack items and registers, for static elimination
# of redundant operations.

atom["dup"]='((s[++sp]=s[sp]))'
atom["over"]='((s[++sp]=s[sp-1]))'
atom["pluck"]='((s[++sp]=s[sp-2]))'
atom["drop"]='((sp--))'
atom["@"]='((s[sp]=m[s[sp]]))'
atom["1+"]='((s[sp]=(s[sp]+1)&maxuint))'
atom["1-"]='((s[sp]=(s[sp]-1)&maxuint))'
atom["2*"]='((s[sp]=(s[sp]<<1)&maxuint))'

atom["negate"]='((s[sp]=(-s[sp]&maxuint)))'
atom["invert"]='((s[sp]^=maxuint))'

atom["s1"]='((s1=s[sp]))'
atom["s2"]='((s2=s[sp-1]))'
atom["s3"]='((s3=s[sp-2]))'
atom["s4"]='((s4=s[sp-3]))'

atom["s1=tmp"]='((s[sp]=tmp))'
atom["s2=tmp"]='((s[sp-1]=tmp))'
atom["s3=tmp"]='((s[sp-2]=tmp))'
atom["s4=tmp"]='((s[sp-3]=tmp))'
atom["tmp=s1"]='((tmp=s[sp-0]))'
atom["tmp=s2"]='((tmp=s[sp-1]))'
atom["tmp=s3"]='((tmp=s[sp-2]))'
atom["tmp=s4"]='((tmp=s[sp-3]))'

atom["s1=s2"]='((s[sp]=s[sp-1]))'
atom["s1=s3"]='((s[sp]=s[sp-2]))'
atom["s2=s1"]='((s[sp-1]=s[sp]))'
atom["s2=s3"]='((s[sp-1]=s[sp-2]))'
atom["s3=s1"]='((s[sp-2]=s[sp]))'
atom["s3=s2"]='((s[sp-2]=s[sp-1]))'
atom["s4=s1"]='((s[sp-3]=s[sp]))'
atom["s4=s2"]='((s[sp-3]=s[sp-1]))'
atom["s4=s3"]='((s[sp-3]=s[sp-2]))'

atom["r@"]='((s[++sp]=r[rp]))'
atom['>r']='((r[++rp]=s[sp--]))'
atom['r>']='((s[++sp]=r[rp--]))'
atom['rdrop']='((r--))'

atom["allot"]='((dp+=s[sp--]))'
atom["here"]='((s[++sp]=dp))'

# ----- colon/semicolon --------------------- #fold00

colon ';'      # semicolon
   code "(( s[sp--] == $magic )) || { unstructured 'no :'; return; }"  # check the magic left by :
   code '(( ${s[sp--]} == ${#body[@]} )) && code ":"'                # insert a noop into empty function bodies
   code 'semicolon'                                                  # compile $lastword from $body[@], resume interpreting
semicolon
immediate

colon ':'      # colon
   code 'word'                                                       # parse space delimited word from input stream
   code 'colon "$word"'                                              # generate synthetic name, associate with word
   code "((s[++sp]=\${#body[@]}))"                                   # allow check of empty function
   code "((s[++sp]=$magic))"                                         # allow check of structure
   code 'compiling=1'
semicolon
interactive

colon 'u:'      # ucolon
   code 'word'                                                       # parse space delimited word from input stream
   code '[[ -z "${headersunresolved["$word"]}" ]] && restrict || colon "$word"'
   code "((s[++sp]=\${#body[@]}))"                                   # allow check of empty function
   code "((s[++sp]=$magic))"                                         # allow check of structure
   code 'compiling=1'
semicolon
interactive

colon 'interactive'                                                  # move header to interpreter context vocabulary
   code 'interactive'
semicolon

colon 'immediate'                                                    # move header to compiler context vocabulary
   code 'immediate'
semicolon


# ----- diagnostics ------------------------- #fold00

words()	{
   local headers
   for tmp in ${headerslistlist[@]} headersunresolved; do
      declare -n headers="$tmp"
	   (( ${#headers[@]} )) && {
         printf '%s\n' "--- ${tmp#"headers"} ---"
   	   printf  "%s  " "${!headers[@]}"
         printf '\n\n'
      }
   done
}

crossref()  {
   local headers
   for tmp in ${headerslistlist[@]} headersunresolved; do
      declare -n headers="$tmp"
      (( ${#headers[@]} )) && {
         printf '%s:\n' "${tmp#"headers"}"
         for tmp2 in "${!headers[@]}"; do
            printf "    %-16s %s\n" "${headers["$tmp2"]}" "$tmp2"
         done | sort -t'_' -k2,2 -n
      }
   done
}

# crossref lists name to word associations.
colon 'crossref'
   code 'crossref'
semicolon
inline

# TODO: factor context voc search.  see also  tick, undoc, forward refs
see()  {
   local headers
   word
   for tmp in "${headerslistlist[@]}"; do
      declare -n headers="$tmp"
      [[ -z "${headers["$word"]}" ]] || {
         printf "found in %s:\n" "${tmp#"headers"}"
         tmp="${headers["$word"]}"
         [[ -z "$tmp" ]] && notfound
         if [[ "$(type -t "$tmp")" == "function" ]]; then
            type "$tmp"
         else
       	   printf "%s\n" "$tmp"
         fi
      }
   done
}

# see word  "decompiles" and shows word.
colon 'see'
   code 'see'
semicolon
inline

colon '.s'
   code '((sp))&&printf "%s " "${s[@]:0:$sp}"'
semicolon
inline



# ----- does> ------------------------------- #fold00

# compiled before return into compling word.
# will therefore be called by create part.
# will consequently know who its caller is
# (function name).  Will also know, by virtue
# of $lastword, what function to add code to.
# (or rather, instruct detokeniser to add code
# to). Appends all defining word associated code
# portion of does> to the original address push
# compiled by create.
dodoes()  {                                                          # append does> part to original address pushing create semantics
   use  "$(type ${headersstateless[$lastword]}|sed '0,/^{/d;$d')
        ${doescode[${FUNCNAME[1]}]}"
}

# detokeniser detects and reacts to this "$does" tagged code:
# code after does> is removed from defining wird and written to
# an array item associated with it.
# dodoes then uses that code to rewrite run time semantics of
# defined word.
# Though somewhat Rube-Goldbergish, it's simpler than the other
# approaches I was thinking of.
colon 'does>'
   code 'code "dodoes" "$does"'
semicolon
immediate

# ----- defining words ---------------------- #fold00


# can be factored, but wait until create related to does> has been sorted out.
colon 'create'
   code 'word'
   code 'constant "$word" "$dp"'
semicolon

colon 'constant'
   code 'word'
   code 'constant "$word" "${s[sp--]}"'
semicolon

colon 'variable'
   code 'word'
   code '((m[dp]=0))'                                                # initialise new variable
   code 'constant "$word" "$((dp++))"'                               # variable is a constant allocating its data and pushing its address
semicolon

colon "array"
   code 'word'                                                       # parse array name
   code 'create "$word"  "$header_code"'                             # create header
   code 'use "((s[sp]+=$dp))"'                                       # set run time semantics
   code "((dp+=s[sp--]))"                                            # allocate
semicolon

# ----- compiler and word search related ---- #fold00

# ( -- 0 | a )
exists() {
   local headers                                                     # meant to spare me from saving and restoring vectored headers variable
   word
   for tmp in "${headerslistlist[@]}"; do                            # loop through all vocs we want to search
      declare -n headers="$tmp"                                      # vector headers to next vocabulary
      [[ -z "${headers["$word"]}" ]] || {                            # word in there?
         tmp="${headers["$word"]}"                                   #     yes: remember name
         [[ $tmp == ${header_code}* ]] || break                      # can not tick data
         ((s[++sp]=${headers["$word"]#"${header_code}_"}))           # convert name to "address" and push
         return 0                                                    # found word, stacked execution token
      }
   done                                                              # go on search next voc
   ((s[++sp]=0))
}


# factor code common with header
# ' foo alias bar
colon 'alias'
   code 'word'
   code 'where["$word"]="$filenr $linenr"'                           # remember file and line nr
   code 'headersstateless["$word"]="${header_code}_${s[sp--]}"'
   code 'flags["$word"]="0"'                                         # default to no flags
semicolon


# NOTE: tick and execute need names to look like foobar_4711
colon "'"
   code 'local headers'                                              # meant to spare me from saving and restoring vectored headers variable
   code 'exists'
   code '((s[sp])) || notfound "$word"'                              # none left -> all searched, but not found.
semicolon

colon "[']"
   exec "'"
   code 'code "((s[++sp]=${s[sp--]}))"'
semicolon
immediate

colon '['
   code 'restricted||compiling=0'                                    # don't allow to suspend compilation when compilation is muted
semicolon                                                            # consequence of above is that any immediate word which modifies stack if not paired
immediate                                                            # must be forbidden to so so by checking restricted state, literal is an example for such a word.

colon ']'
   code 'compiling=1'
semicolon

colon 'literal'
   code 'restricted || {'
   code 'code "((s[++sp]=${s[sp--]}))"'
   code '}'
semicolon
immediate

colon 'execute'
   code "${header_code}_\${s[sp--]}"
semicolon
inline

colon 'trash'
   code 'word'
   code 'unset "headersstateless[$word]"'
semicolon

# ( xt -- ) ( string: -- $1 )
colon 'name'
   code 'ss+=("${names[s[sp--]]}")'
semicolon

# set header flag for inline compilation
# can be used after a colon definition
colon 'inline'
   code 'inline'
semicolon

colon 'resolve'
   code 'resolve'
semicolon
inline

colon '.unresolved'
   code '((${#headersunresolved[@]}))&&printf "%s " "${!headersunresolved[@]}"'
semicolon
inline

colon '#unresolved'
   code '((s[++sp]=${#headersunresolved[@]}))'
semicolon
inline

# use recurse instead of word name to recurse into, as being
# able to refer to itself by name in a definition is due to change.
colon 'recurse'
   code 'code "${headersstateless["$lastword"]}"'
semicolon
immediate



# ----- environment-------------------------- #fold00
# read number from environment variable with name on string stack
# ( -- x )  ( string:  $1 -- )
colon 'env'
   code '((s[++sp]=${!ss[-1]}))'
   code 'unset "ss[-1]"'
semicolon
inline
inout 0 1

# store $1 in bash environment variable with name $2
# ( x -- ) ( string:  $1 -- )
colon '>env'
   code 'eval "${ss[-1]}=$((s[sp--]))"'
   code 'unset "ss[-1]"'
semicolon
inout 1 0


# read string from environment variable with name on string stack
# ( string:  $1 -- $2 )
colon 'env$'
   code 'ss[-1]="${!ss[-1]}"'
semicolon
inline
inout 0 0

# store string $1 in bash environment variable with name $2
# ( string:  $1 $2 -- )
colon '>env$'
   code 'eval "${ss[-1]}=${ss[-2]}"'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon
inout 0 0



# ----- misc -------------------------------- #fold00

colon 'noop'
   code ':'
semicolon
inline

colon "\\"                                                           # double quoted escaped backslash rather than
   code 'line=""'                                                    # single quoted single backslash because
semicolon                                                            # efte syntax highlighting gets confused
interactive

colon "\\"                                                           # double quoted escaped backslash rather than
   code 'line=""'                                                    # single quoted single backslash because
semicolon                                                            # efte syntax highlighting gets confused
immediate

colon '('
   code "parse ')'"
semicolon
interactive

colon '('
   code "parse ')'"
semicolon
immediate

# ----- parameter stack --------------------- #fold00


colon 'dup'
   atom 'dup'
semicolon
inline
inout 1 2

colon 'drop'
   atom 'drop'
semicolon
inline
inout 1 0

colon 'over'
   atom 'over'
semicolon
inline
inout 2 3

colon 'pluck'
   atom 'pluck'
semicolon
inline
inout 3 4

colon '2dup'
   atom 'over'
   atom 'over'
semicolon
inline
inout 2 4

colon '2drop'
   atom 'drop'
   atom 'drop'
semicolon
inline
inout 2 0

colon '2over'
   code '((s[++sp]=s[sp-3]))'
   code '((s[++sp]=s[sp-3]))'
semicolon
inline
inout 4 6

colon 'swap'
   atom 'tmp=s2'
   atom 's2=s1'
   atom 's1=tmp'
semicolon
inline
inout 2 2

colon '2swap'
   atom 'tmp=s4'
   atom 's4=s2'
   atom 's2=tmp'
   atom 'tmp=s3'
   atom 's3=s1'
   atom 's1=tmp'
semicolon
inout 4 4

colon 'nip'
   atom 's2=s1'
   atom 'drop'
semicolon
inline
inout 2 1

colon 'tuck'
   atom 'dup'
   atom 's2=s3'
   atom 's3=s1'
semicolon
inline
inout 2 3

colon 'rot'
   atom 'tmp=s1'
   atom 's1=s3'
   atom 's3=s2'
   atom 's2=tmp'
semicolon
inline
inout 3 3

colon '-rot'
   atom 'tmp=s1'
   atom 's1=s2'
   atom 's2=s3'
   atom 's3=tmp'
semicolon
inline
inout 3 3

colon '?dup'
   code '((s[sp])) &&'
   atom 'dup'
semicolon
inline

colon 'depth'
   code '((s[++sp]=$sp))'
semicolon
inline

colon 'pick'
   code '((s[++sp]=s[sp-s[sp]]))'
semicolon
inline

# ----- return stack ------------------------ #fold00

colon 'r@'
   atom 'r@'
semicolon
inline
inout 0 1

colon 'rdrop'
   atom 'rdrop'
semicolon
inline
inout 0 0

colon '>r'
   atom '>r'
semicolon
inline
inout 1 0

colon 'r>'
   atom 'r>'
semicolon
inline
inout 0 1

colon 'rdepth'
   code '((s[++sp]=rp))'
semicolon
inout 0 1
inline

# ----- string stack ------------------------ #fold00

colon 'depth$'
   code 's+=("${#ss[@]}")'
semicolon
inline

colon 'empty$'
   code 'ss=()'
semicolon
inline

colon 'dup$'
   code 'ss+=("${ss[-1]}")'
semicolon
inline

colon '?dup$'
   code '[[ -z ${ss[-1]} ]] || ss+=("${ss[-1]}")'
semicolon
inline

colon 'drop$'
   code 'unset "ss[-1]"'
semicolon
inline

colon 'over$'
   code 'ss+=("${ss[-2]}")'
semicolon
inline

colon 'pluck$'
   code 'ss+=("${ss[-3]}")'
semicolon
inline

colon 'pick$'
   code 'ss+=("${ss[-s[sp--]-1]}")'
semicolon
inline

colon '2dup$'
   code 'ss+=("${ss[-2]}")'
   code 'ss+=("${ss[-2]}")'
semicolon
inline

colon '2drop$'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon
inline

colon '2swap$'
   code 'tmp="${ss[-4]}"; ss[-4]="${ss[-2]}"; ss[-2]="$tmp"'
   code 'tmp="${ss[-3]}"; ss[-3]="${ss[-1]}"; ss[-1]="$tmp"'
semicolon
inline

colon 'swap$'
   code 'tmp="${ss[-2]}"; ss[-2]="${ss[-1]}"; ss[-1]="$tmp"'
semicolon
inline

colon 'nip$'
   code 'ss[-2]="${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon
inline

colon 'tuck$'
   code 'ss+=("${ss[-1]}"); ss[-2]="${ss[-3]}"; ss[-3]="${ss[-1]}"'
semicolon
inline

colon 'rot$'
   code 'tmp="${ss[-1]}"; ss[-1]="${ss[-3]}"; ss[-3]="${ss[-2]}"; ss[-2]="$tmp"'
semicolon
inline

colon '-rot$'
   code 'tmp="${ss[-1]}"; ss[-1]="${ss[-2]}"; ss[-2]="${ss[-3]}"; ss[-3]="$tmp"'
semicolon
inline

colon 'trim$'
   code 'ss[-1]="${ss[-1]//[[:space:]]/}"'
semicolon
inline

# ( -- u )  string: ( $1 $2 -- $3 )     remove  $2* from $1, return removed chars count
colon 'cut$'
   code '((s[++sp]=${#ss[-2]}))'
   code 'ss[-2]="${ss[-2]%${ss[-1]}*}"'
   code '((s[sp]-=${#ss[-2]}))'
   code 'unset "ss[-1]"'
semicolon

# count substring occurances
# : #substrings  swap$ 0 begin over$ cut$ while 1+ repeat 2drop$ ;

# -leading$:  ${myVar##*( )}
# -trailing$: ${myVar%%*( )}

colon '.ss'
   code '((${#ss[@]})) &&'
   code 'printf "\"%s\" " "${ss[@]}"'
semicolon

colon 'type$'
   code 'printf "%s" "${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon
inline

colon 'count$'
   code '((s[++sp]=${#ss[-1]}))'
   code 'unset "ss[-1]"'
semicolon
inline

# split string into single words at white space, return count of resulting single word strings.
# ( -- u )   ss: ( $ -- $1 $2 $3 §.. $u )
colon 'chop$'
   code 'tmp="${ss[-1]}"'
   code 'unset "ss[-1]"'
   code 's1=("${#ss[@]}")'
   code 'ss+=($tmp)'
   code '((s[++sp]=${#ss[@]}-s1))'
semicolon

# ---------- command ---------      - output -        ----- mnemonic -----
# "abcdefgh"   2 left$   type$      ab                "keep 2 left"
# "abcdefgh"  -2 left$   type$      abcdef            "keep left all but last 2"
# "abcdefgh"   2 right$  type$      gh                "keep 2 right"
# "abcdefgh"  -2 right$  type$      cdefgh            "keep right all but first 2"
# "abcdefgh"   2 split$  type$      ab cdefgh         "split at left"
# "abcdefgh"  -2 split$  type$      abcdef gh         "split at right"

colon 'left$'
   code 'ss[-1]=${ss[-1]:0:s[sp--]}'
semicolon
inline

colon 'right$'
   code 'ss[-1]=${ss[-1]:0-s[sp--]}'
semicolon
inline

colon 'mid$'
   code 'ss[-1]=${ss[-1]:s[sp-1]:s[sp--]}'
   atom 'drop'
semicolon

colon 'split$'
   code 'ss+=("${ss[-1]:s[sp]}")'
   code 'ss[-2]="${ss[-2]:0:s[sp--]}"'
semicolon

colon 'join$'
   code 'ss[-2]+="${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon
inline

colon '$='
   code '[[ ${ss[-1]} != ${ss[-2]} ]];s[++sp]="-$?"'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

colon '$<'
   code '[[ ${ss[-1]} > ${ss[-2]} ]];((s[++sp]=$?-1))'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

colon '$>'
   code '[[ ${ss[-1]} < ${ss[-2]} ]];((s[++sp]=$?-1))'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

# "nice"    "this is a very *** foo"   "***" replace$    ->   "this is a very nice foo"
# "nope"    "this is a very *** foo"   "?" replace$      ->   "this is a very *** foo"
# "123"     "abcd" 1 insert$  -> "a123bcd"

asc()  {
   if [[ -z "${ss[-1]}" ]]; then
      ((s[++sp]=0))
   else
      ((s[++sp]=${asc[${ss[-1]:0:1}]}))
      ss[-1]="${ss[-1]:1}"
   fi
}

colon 'asc'
   code 'asc'
semicolon

colon 'char$'
   code 'ss+=("${char[s[sp--]]}")'
semicolon

# $ -> a -- n
unpackstring()  {
   string="${ss[-1]}"
   unset "ss[-1]"
   ((tmp="${#string}", s1=s[sp]))
   for ((len=0; tmp--;)); do
      ((m[s1++]="asc[${string:len++:1}]"))
   done
   ((s[sp]="$len"))
}
colon 'unpack$'
   code 'unpackstring'
semicolon

# ( a n -- ) ( string: -- $ )
colon 'pack$'
   atom 's1'
   atom 's2'
   atom 'drop'
   atom 'drop'
   code 'tmp=""'
   code 'for ((; s1--; )); do tmp+="${char[m[s2++]]}"; done'
   code 'ss+=("$tmp")'
semicolon

# ----- bit logic --------------------------- #fold00

colon 'and'
   code '((s[sp-1]&=s[sp--]))'
semicolon
inline

colon 'or'
   code '((s[sp-1]|=s[sp--]))'
semicolon
inline

colon 'xor'
   code '((s[sp-1]^=s[sp--]))'
semicolon
inline

colon 'invert'
   atom 'invert'
semicolon
inline

colon lshift
   code '((s[sp]=(s[sp-1]<<s[sp--])&maxuint))'
semicolon
inline

colon rshift
   code '((s[sp-1]>>=s[sp--]))'
semicolon
inline

evaluate "' lshift alias <<"
evaluate "' rshift alias >>"

# ----- comparison -------------------------- #fold00

colon '0='
   code '((s[sp]=s[sp]?0:maxuint))'                                  # &msb: 0->maxuint  x->0
semicolon
inline

colon '0<'
   code '((s[sp]=s[sp]&msb?maxuint:0))'                              # &msb: 0->0   msb->maxuint
semicolon
inline

colon '='
   code '((s1=s[sp--]))'
   code '((s[sp]=(s[sp])==(s1)?maxuint:0))'
semicolon
inline

colon '<>'
   code '((s1=s[sp--]))'
   code '((s[sp]=(s[sp])==(s1)?0:maxuint))'
semicolon
inline

colon 'u<'
   code '((s1=s[sp--]&maxuint))'
   code '((s[sp]=(s[sp]&maxuint)<(s1)?maxuint:0))'
semicolon
inline

colon 'u>'
   code '((s1=s[sp--]&maxuint))'
   code '((s[sp]=(s[sp]&maxuint)>(s1)?maxuint:0))'
semicolon
inline

# broken. only valid for numbers 0..maxint
colon '<'
   code '((s1=s[sp--]))'
   code '((s[sp]=(s[sp])<(s1)?maxuint:0))'
semicolon
inline

# broken. only valid for numbers 0..maxint
colon '>'
   code '((s1=s[sp--]))'
   code '((s[sp]=(s[sp])>(s1)?maxuint:0))'
semicolon
inline

# ----- arithmetics ------------------------- #fold00

colon '1+'
   atom '1+'
semicolon
inline
inout 1 1

colon '1-'
   atom '1-'
semicolon
inline
inout 1 1

colon '2*'
   atom '2*'
semicolon
inline
inout 1 1

colon '2/'
   code '((s[sp]=(s[sp]>>1)|(s[sp]&msb)))'
semicolon
inline
inout 1 1

evaluate ': cells ;'      ; immediate  ; inout 1 1
evaluate ': cells ;'      ; interactive; inout 1 1
evaluate ': cell+ 1+ ;'   ; inline;   inout 1 1

colon '+'
   code '((s[sp]=(s[sp-1]+s[sp--])&maxuint))'
semicolon
inline
inout 2 1

colon '-'
   code '((s[sp]=(s[sp-1]-s[sp--])&maxuint))'
semicolon
inline
inout 2 1



#                     msb&    msb&
#  s3 s2 s1 -- r q  s1^s2^s3  s2^s3
# ---------------------------------
#  +  +  +     + +     0       ß0
#  +  +  -     + -     1        0
#  +  -  +     - -     1        1
#  +  -  -     - +     0        1
#  -  +  +     - -     1        1
#  -  +  -     - +     0        1
#  -  -  +     + +     0        0
#  -  -  -     + -     1        0
# ( s3 s2 s1  -- s3*s2%s1 s3*s2/s1 )
colon '*/mod'
   atom 's1'
   atom 's2'
   atom 's3'
   atom 'drop'
   code '((signr=(s2^s3)))'                                          # 0:+   x:-
   code '((signq=(signr^s1)))'                                       # 0:+   x:-
   code '((s1&msb&&(s1=-s1&maxuint)))'                               # abs s1
   code '((s2&msb&&(s2=-s2&maxuint)))'                               # abs s2
   code '((s3&msb&&(s3=-s3&maxuint)))'                               # abs s3
   code '((tmp=s2*s3))'
   code '((s[sp-1]=(signr&msb?-tmp%s1:tmp%s1)))'
   code '((s[sp]=(signq&msb?-tmp/s1:tmp/s1)))'
semicolon
inout 3 2

evaluate ': */     */mod nip ;'         ; inline; inout 3 1
evaluate ': /mod   1 -rot  */mod  ;'    ; inline; inout 2 2
evaluate ': *      1 */    ;'           ; inline; inout 2 1
evaluate ': /      /mod nip  ;'         ; inline; inout 2 1
evaluate ': mod    /mod drop  ;'        ; inline; inout 2 1

colon 'negate'
   atom 'negate'
semicolon
inline
inout 1 1

colon '?negate'
   code '((s[sp--]))&&'
   atom 'negate'
semicolon
inline
inout 2 1

colon 'abs'
   code '((s[sp]&msb))&&'
   atom 'negate'
semicolon
inline
inout 1 1

# needs testing
colon 'u/mod'		# u1 u2 -- rem quot
   code '((s1=s[sp]&maxuint, s2=s[sp-1]&maxuint, s[sp]=s2/s1, s[sp-1]=s2%s1))'
semicolon
inline
inout 3 2

# ----- memory ------------------------------ #fold00

colon '@'
   atom '@'
semicolon
inline
inout 1 1

colon 'skim'
   code '((s[++sp]=m[s[sp]++]))'
semicolon
inline
inout 1 2

colon 'count'
   code '((s[++sp]=m[s[sp]++]&255))'
semicolon
inline
inout 1 2

colon '!'
   code '((m[s[sp--]]=s[sp-1]))'
   atom 'drop'
semicolon
inline
inout 2 0

colon '<-'                       # swap !
   code '((m[s[sp]]="s[sp--]"))'
   atom 'drop'
semicolon
inout 2 0

colon '+!'
   code '((m[s[sp--]]=(s[sp-1]+m[s[sp]])&maxuint))'
   atom 'drop'
semicolon
inline
inout 2 0

colon 'on'
   code '((m[s[sp--]]=maxuint))'
semicolon
inline
inout 1 0

colon 'off'
   code '((m[s[sp--]]=0))'
semicolon
inline
inout 1 0

# ( x1 a -- x2 )
colon 'exchange'
   code '((tmp=m[s[sp]]))'
   code '((m[s[sp]]=s[sp-1]))'
   code '((s[--sp]=tmp))'
semicolon
inout 2 1

colon 'here'
   atom 'here'
semicolon
inline
inout 0 1

colon 'allot'
   atom 'allot'
semicolon
inline
inout 1 0

colon ','
   code '((m[dp++]=s[sp--]))'
semicolon
inline
inout 1 0

# pad is 256 cells above here.
colon 'pad'
   code '((s[++sp]=dp+256))'
semicolon
inline
inout 0 1

# c -> m[a++],  u times
# ( a u c -- )
colon 'fill'
   code '((s1=s[sp--]))'
   code '((s2=s[sp--]))'
   code '((s3=s[sp--]))'
   code 'for ((;s2--;)); do'
   code '((m[s3++] = s1))'                                           # c -> m[a++],  u times
   code 'done'
semicolon
inout 3 0


# 0 -> m[a++],  u times
# ( a u -- )
evaluate ': erase   0 fill ;'    ; inline; inout 2 0

# ( a1 a2 u -- )
move()  {                                                            # deals with destination overlapping source
   ((s1=s[sp--], s2=s[sp--], s3=s[sp--]))
   if ((s3 < s2)); then                                              # copy highest to lowest:
      ((s2+=s1, s3+=s1))                                             # m[--a1+u} -> m[--a2+u],  u times
      for ((;s1--;)); do
         ((m[--s2] = m[--s3]))
      done
   else                                                              # copy lowest tio highest
      for ((;s1--;)); do                                             # m[a1++} -> m[a2++],  u times
         ((m[s2++] = m[s3++]))
      done
   fi
}

# ( a1 a2 u -- )
colon 'move'
   code 'move'
semicolon
inline
inout 3 0

# ----- flow control ------------------------ #fold00

remagic

colon 'if'
   code 'code "if ((s[sp--])); then"'
   code "((s[++sp]=\${#body[@]}))"                                   # allow check of empty function
   code "((s[++sp]=$magic))"                                         # allow check of structure and empty function
semicolon
immediate

colon 'else'
   code "(( s[sp]++ == \"$magic\" )) || { unstructured 'no if'; return; }"
   code '(( s[sp-1] == ${#body[@]} )) && code ":"'
   code 'code "else"'
   code '((s[sp-1]=${#body[@]}))'
semicolon
immediate

colon 'then'
   code "(( s[sp] == $magic ||  s[sp] == $((magic+1)) )) || { unstructured 'no if or else'; return; }"
   atom 'drop'
   code '(( s[sp--] == ${#body[@]} )) && code ":"'
   code 'code "fi"'
semicolon
immediate


remagic

colon 'begin'
   code 'code "while :; do"'
   code "((s[++sp]=\${#body[@]}))"                                   # allow check of empty function
   code "((s[++sp]=$magic))"                                         # allow check of structure and empty function
semicolon
immediate


colon 'again'
   code "(( s[sp--] == \"$magic\" )) || { unstructured 'no begin'; return; }"
   code '(( s[sp--] == ${#body[@]} )) && code ":"'
   code 'code "done"'
semicolon
immediate

colon 'until'
   code "(( s[sp--] == \"$magic\" )) || { unstructured 'no begin'; return; }"
   code 'code "((s[sp--]))&&break"'
   atom 'drop'
   code 'code "done"'
semicolon
immediate

colon 'while'
   code "(( s[sp]++ == $magic )) || { unstructured 'no begin'; return; }"
   code 'code "((s[sp--]))||break"'
semicolon
immediate

colon 'repeat'
   code "(( s[sp--] == $((magic+1)) )) || { unstructured 'no while'; return; }"
   atom 'drop'
   code 'code "done"'
semicolon
immediate


remagic
colon 'for'
   code 'code "((r[++rp]=i))"'
   code 'code "((i=s[sp--]))"'
   code 'code "for ((; i--; )); do"'
   code "((s[++sp]=\${#body[@]}))"                                   # allow check of empty function
   code "((s[++sp]=$magic))"                                         # allow check of structure and empty function
semicolon
immediate

colon 'i'
   code '((s[++sp]=i))'
semicolon
inline
inout 0 1

evaluate ': j r@ ;'   ; inline;  inout 0 1

colon 'next'
   code "((s[sp--] == $magic))|| { unstructured 'no for'; return; }"
   code '((s[sp--] == ${#body[@]})) && code ":"'
   code 'code "done"'
   code "code '((i=r[rp--]))'"
semicolon
immediate


remagic

dodo()  {
   ((r[++rp]=ibar))
   ((r[++rp]=i))
   ((i=s[sp--]))
   ((ibar=s[sp--]))
}

colon 'do'
   code 'code "dodo"'
   code 'code "while :;do"'
   code "((s[++sp]=$magic))"                                         # allow check of structure and empty function
semicolon
immediate

colon 'loop'
   code "((s[sp--] == $magic))|| { unstructured 'no do'; return; }"
   code 'code "((++i < ibar))||break"'
   code 'code "done"'
   code "code '((i=r[rp--]))'"
   code "code '((ibar=r[rp--]))'"
semicolon
immediate

colon '+loop'
   code "((s[sp--] == $magic))|| { unstructured 'no do'; return; }"
   code 'code "((s1=s[sp--]))"'
   code 'code "((i+=s1))"'
   code 'code "((((ibar-(s1<msb)-i)^s1)&msb))&&break"'
   code 'code "done"'
   code "code '((i=r[rp--]))'"
   code "code '((ibar=r[rp--]))'"
semicolon
immediate

colon 'leave'
   code 'code "break"'
semicolon
immediate

colon '?leave'
   code 'code "((s[sp--]))&&break"'
semicolon
immediate

# compiled version: skip until end of word on false
colon 'lest'
   code 'code "((s[sp--]))||return" '
semicolon
immediate    # compile only are inherently immediate

# interpreted version: skip rest of line when false
colon 'lest'
   code '((s[sp--]))||line=""'
semicolon
interactive

# compiled version: skip until end of word on true
colon 'unless'
   code 'code "((s[sp--]))&&return" '
semicolon
immediate    # compile only are inherently immediate

# interpreted version: skip rest of line when true
colon 'unless'
   code '((s[sp--]))&&line=""'
semicolon
interactive

# evaluate input line until end u times
colon 'times'
   code '((r[++rp]=i))'
   code '((i=s[sp--]))'
   code 'while ((i--)); do evaluate "$line"; done'
   code '((i=r[rp--]))'
   atom 'rdrop'
   code 'line=""'
semicolon
interactive

# this is the prefered version, repeating the line upon encountering many
# prefered because its use is more symmetrical with times, both specified
# before the repeated sequence.  times is harder to put at the end.
colon 'many'
   code 'until read -rsn1 -t 0.01; do evaluate "$line"; done'
   code 'line=""'
semicolon


colon 'warm'
   code 'warm'
semicolon

colon 'boot'
   code 'word'
   code 'need "$word"'                                               # cold entry may come from postlib
   code 'resolve'                                                    # in which case we want it now
   code 'coldvector="${headersstateless["$word"]}"'                  # because writing it to cold start vector
semicolon                                                            # this way cold start entry points can be forward referenced


colon 'bye'
   code 'exit 0'
semicolon


colon 'exit'
   code 'return'
semicolon
inline
immediate

# ( err -- )
colon 'abort'
   code 'abort "${s[sp--]}"'
semicolon

# ( f err -- )
colon '?abort'
   code '((s[sp-1]))&&abort "${s[sp]}"'
   atom 'drop'
   atom 'drop'
semicolon


# ----- conditional compilation-------------- #fold00

# need can create forward ref even though forward refs are turned off.
# resolving will still be done, that way can specific words (and their
# dependencies) be picked from forward lib.
# arg1: name of needed word,  arg2; referrer
need()  {                                                            # only ask for forward if word isn't in any context voc
   [[ -z "${headersstateless[$1]}" ]] || return
   [[ -z "${headersinterpretonly[$1]}" ]] || return
   [[ -z "${headerscompileonly[$1]}" ]] || return
   forwardref "$1"  "$2"
}

colon 'need'
   code 'word'
   code 'need "$word" ""'                                            # empty arg indicates explicit need, no referrer
semicolon

# ( -- f )     check unresolved status of word
colon 'needed'
   code 'word'
   code '[[ "${headersunresolved["$word"]}" ]]'
   code '((s[++sp]=${?}?0:maxuint))'
semicolon

colon 'exists'
   code 'exists'
semicolon

# ----- i/o --------------------------------- #fold00

colon 'esc['
   code 'printf "\e[%s" "${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon
inline
inout 1 0

colon 'ansi'
   code 'printf "\e[%bm" "${s[sp--]}"'
semicolon
inline
inout 1 0

colon 'at'
   code '((s1=s[sp--]+1, s2=s[sp--]+1))'
   code 'printf "\e[%b" "${s1};${s2}H"'
semicolon
inline
inout 2 0

colon 'emit'
   code 'printf "%c" "${char[s[sp--]&255]}"'                         # given an ASCII, print the character
semicolon
inline
inout 1 0

evaluate ': type  pack$ type$ ;'  ; inline;  inout 2 0

colon 'parse$'
   code 'parse "${ss[-1]}"'
   code 'ss[-1]="$word"'
semicolon

colon 'parse'
   code 'parse "${char[s[sp--]]}"'
   code 'ss+=("$word")'
semicolon


keybuf=""
colon 'key'
   code 'if [[ -z "$keybuf" ]]; then'                                # key? may have put chars into keybuf
   code 'IFS="" read -rsn1 tmp'                                      # keybuf empty: read from console
   code 'keybuf+="${tmp}"'                                           # consider space if -z $tmp
   code 'fi'
   code 'tmp="${keybuf:0:1}"'                                        # read key from keybuf
   code 'tmp=$(printf "%d" '"\"'""\${tmp}\")"                        # treat ctrls as spaces, convert to ASCII
   code '((s[++sp]=tmp))'                                            # push ASCII
   code 'keybuf="${keybuf:1}"'                                       # strip key from keybuf
semicolon
inout 0 1

colon 'key?'
   code '[[ -z "$keybuf" ]] || { s+=("$maxuint"); return; }'         # key in keybuf: yes, flag "key ready"
   code 'IFS=""'                                                     # no key in keybuf: poll console
   code 'if read -rsn1 -t0.01 tmp; then'
   code 'keybuf+="$tmp"'                                             # add key to buffer. maybe add space if -z $tmp
   code '((s[++sp]=maxuint))'
   code 'return'
   code 'fi'
   code '((s[++sp]=0))'
semicolon
inout 0 1

# read line into tib
# TODO: configurable ANSI sequences
query()  {
   printf '\e[3%sm' "$green"
   IFS="" read -er -i "$keybuf" tib                                  # key? may have put chars into keybuf
   keybuf=""
   printf '\e[%sm' "$normal"
}
colon 'query'
   code 'query'
semicolon
inout 0 0

colon 'evaluate'
   code 'evaluate "$tib"'
semicolon
inline

colon 'evaluate$'
   code 'local tib="${ss[-1]}"'
   code 'unset "ss[-1]"'
   code 'evaluate "$tib"'
semicolon
inline

colon 'cr'
   code 'printf "\n"'
semicolon
inline
inout 0 0

colon 'space'
	code 'printf " "'
semicolon
inline
inout 0 0

colon 'spaces'
   code '((s1=s[sp--]))'
   code '((s1&msb))||printf "%${s1}s" ""'
semicolon
inout 1 0

colon 'page'
   code 'clear'
semicolon
inline
inout 0 0

prompt()  {
   ((error)) && {
      warm
      return 1
   }

   ((compiling)) && {
      printf "|%-4s" ""                                              # just a vertical bar, then indenting, while compiling
      return 0
   }
   printf " %s" "ok"                                                 # ok prompt
   ((${#s[@]})) &&  {                                                # stack depth > 0?
      tmp=".........+"                                               # yes: print a dot for each item
      printf " %s" "${tmp:0:$sp}"                                    # but not more than in $tmp
   }
   ((${#headersunresolved[@]})) &&  {                                # unresolved words > 0?
      printf " (%d)" "${#headersunresolved[@]}"                      # yes: show count
   }
   printf "\n"                                                       # finalize with linefeed
}

colon 'prompt'
   code 'prompt'
semicolon
inline


colon 'from$'
   code 'file="${ss[-1]}"'
   code 'unset "ss[-1]"'
   code 'from "$file"||filenotfound "$file"'
semicolon
inline

evaluate ': from bl parse from$ ;'


colon '#files'
   code '((s[++sp]=${#files[@]}))'
semicolon
inline
inout 0 1


colon 'files'
   code 'printf "%s\n" "${files[@]}"|nl'                             # show list of already included files
semicolon


# ----- pictured number conversion ---------- #fold00


colon 'decimal'
   code 'm[base]="10"'
semicolon
inline
inout 0 0

colon 'hex'
   code 'm[base]="16"'
semicolon
inline
inout 0 0

colon 'binary'
   code 'm[base]="2"'
semicolon
inline
inout 0 0

# ( string: -- $1 )
colon '<#'
   code 'ss+=("")'
semicolon
inline
inout 0 0


# ( x1 -- x2 ) ( string: $1 -- $2 )
colon '#'
   code '((radix=m[base]))'
   code '((s1=s[sp]&maxuint, s[sp]=s1/radix, tmp=s1%radix+48))'
   code '((tmp>57))&&((tmp+=39))'
   code 'ss[-1]="${char[tmp]}${ss[-1]}"'
semicolon
inout 1 1

# ( x1 -- x2 ) ( string: $1 -- $2 )
colon '#s'
   code 'while :; do'
   code '${headersstateless["#"]}'
   code '((s[sp]))||break'
   code 'done'
semicolon
inout 1 1

# ( asc -- ) ( string: $1 -- $2 )
colon 'hold'
   code 'ss[-1]="${char[s[sp--]]}${ss[s-1]}"'
semicolon
inline
inout 1 0

# ( n -- ) ( string: $1 -- $2 )
colon 'sign'
  code '((s[sp--]&msb))&&ss[-1]="-${ss[-1]}"'
semicolon
inline
inout 1 0

evaluate ': #>$      drop ;'                       ; inline; inout 1 0    # ( x -- )
evaluate ': #>type   #>$ type$ ;'                  ; inline; inout 1 0    # ( x -- ) ( string:  $1 -- )
evaluate ': #>       #>$ here here unpack$ ;'      ;         inout 1 2    # ( x -- a n ) ( string:  $1 -- )
evaluate ': .padded  dup$ count$ - spaces type$ ;' ;         inout 1 0    # ( u -- ) (string: $1 -- )
evaluate ': uconvert <# #s #>$ ;'                  ; inline; inout 1 0    # ( u -- ) (string: -- $1 )
evaluate ': convert  dup abs uconvert sign ;'      ;         inout 1 0    # ( u -- ) (string: -- $1 )
evaluate ': .r       >r convert  r> .padded ;'     ;         inout 2 0    # ( n u -- )
evaluate ': u.r      >r uconvert r> .padded ;'     ;         inout 2 0    # ( u1 u2 -- )
evaluate ': .        0  .r space ;'                ; inline; inout 1 0    # ( n -- )
evaluate ': u.       0 u.r space ;'                ; inline; inout 1 0    # ( u -- )
evaluate 'trash .padded'


# convert a string representation of a number
# or arithmetic expression to an integer
# respects base
# ( -- x ) (string: $1 -- )
colon 'convert$'
   code '((s[++sp]=${m[base]}#${ss[-1]}))'
   code 'unset "ss[-1]"'
semicolon
inline
inout 0 1



# ----- documentation ----------------------- #fold00


undoc_template()  {
cat << EOF
created:             auto     (remove line after having checked and revised description)
name:                $1
stack:               ( -- )
return stack:        ( -- )
string stack:        ( -- )
category:
input stream:
decription:          none
contexts:            interpreting, compiling
example:             none
notes:               none
EOF
}

undoc()  {
   for word in "${!headers[@]}"; do                                  # run through all headers
      name="$worddoc:${word/\//U+0002F;}"
      [[ -f "$name" ]] || {                                          # found one for which no doc file exists
         undoc_template "$word" >"$name"
         editor "$name"
         break
      }
   done
}
colon 'undoc'
   code 'undoc'
semicolon

# factor
doc()       { editor "$worddoc:${1/\//U+0002F;}"; }
about()     { cat    "$worddoc:${1/\//U+0002F;}"; }

colon 'doc'
   code 'word'
   code 'doc "$word"'
semicolon

colon 'about'
   code 'word'
   code 'about "$word"'
semicolon


# topics
# n topic

colon 'topics'
   code 'unset "GLOBIGNORE"'
   code 'printf "%s\n" "$topicdoc"/* | sed "s/.*\///" | nl'
   code 'GLOBIGNORE="*:?"'
semicolon

# ( u -- )
colon 'topic'
   code 'unset "GLOBIGNORE"'
   atom 's1'
   atom 'drop'
   code '((s1)) && { topics=("$topicdoc"/*)'
   code 'editor "${topics[s1-1]}"; }'
   code 'GLOBIGNORE="*:?"'
semicolon

helptext() {
cat << EOT
   Information is available on selected topics.
   To see a list of topics, execute:            topics
   to read about first topic, execute:          1 topic
   Any other listed topic can be opened
   by using the number next to it,
   in place for 1

   A list of included source files can be
   shown by executing:                          files
   These too are numbered. Use that
   number with commands like list and
   edit:                                        1 list
                                                2 edit
   "edit" assumes that yoda knows how to
   open a properly working editor on your
   system. Read topic "configuration" to
   find out how to set up yoda to use
   your preferred editor.

   A list of words understood by yoda
   can be seen by executing:                    words
   Another list shows when entering:            crossref

   Documentation about those words can
   be opened by executing:                      doc name
   where "name" is the name of the word
   you want information about.

   With a configured editor, opening the
   source file of any word and jumping
   to the line with the definition to UTSL
   is done with:                                review name
   I am tempted drop the doc feature
   entirely, move docs to source files and
   suggest to use review instead of doc.
   review complements see, which decompiles:    see name
EOT
}
colon 'help'
   code 'helptext'
semicolon



# ----- convenience ------------------------- #fold00
# TODO: optimiser: invalidate all stack register contents
colon 'empty'
   code 's=() sp=0'
semicolon
inline

# empty stack and string stack
# since warm doesn't empty them any longer, a convenient
# way to do so manually was needed.
colon '_'
   code 's=() sp=0'
   code 'ss=()'
semicolon
inline

colon 'secs'
	code 'sleep "${s[sp--]}"'
semicolon
inline

colon 'words'
   code "words"
semicolon

colon 'edit'
   code '((s1=s[sp--]))'
   code '((s1))&&editor "${files[s1-1]}"'
semicolon

colon 'list'
   code '((s1=s[sp--]))'
   code '((s1))&&cat "${files[s1-1]}"'
semicolon

# a microseconds epoch, used for benchmarking
colon 'realtime'
   code '((s[++sp]=${EPOCHREALTIME//,/}))'
semicolon
inline
inout 0 1

# ----- experimental ------------------------ #fold00

# leftovers from running quit as coproc, exiting by error and
# therefore having a word - the word calling quit - as outermost
# error handler. While this works, it suffers from that along
# with the quit session (which gets terminated) also all compiled
# words go bust. That behavior is a tad harsh for dealing with
# errors which may simply be a typo. But leeping them in, who knows
# what else they may come in handy with.
# similar to execute, but seperate process
colon 'coproc'
   atom 's1'
   atom 'drop'
   code "coproc ${header_code}_\${s1} < /dev/tty > /dev/tty"
   code 'echo "coproc return value=$?"'
   code 'echo "coproc fd=${COPROC[@]}"'
semicolon

colon 'wait'
   code 'echo "wait fd=${COPROC[@]}"'
   code 'echo "wait pid=$COPROC_PID"'
   code 'wait -n -p pid $COPROC_PID'
   code 'ret="$?"'
   code '((ret==255))&&exit 255'
   code 'echo "wait return value=$ret"'
   code 'echo "wait pid=$pid"'
semicolon


if false; then             ä# don't want this

# trying autoresolving word stubs. Eventually created using a
# defining word, these are hand contructed for testing purposes:
# Upon execution, resolve word from library, then execute it.
autoresolvingwordstub()  {
   unset "headersstateless[$1]"
   need "$1"
   resolve
   [[ -z ${headersstateless["$1"]} ]]||
   ${headersstateless["$1"]}
}

colon 'hello'           # should resolve from postlib, then execute
   code "autoresolvingwordstub \"$lastword\""
semicolon

colon 'nothello'        # not resolving. test error case
   code "autoresolvingwordstub \"$lastword\""
semicolon

# approach isn't ideal: while apparently working, even in this
# case of ...
#   : foo hello ;
#   hello
#   foo foo foo
# ... this hides the problem that every time foo is executed,
# hello header is trashed, then resolved from library another time.
# using "use" should be a better approach, as it keeps word name
# steady, but redefines the function with the same name.

fi

# ----- unsorted ---------------------------- #fold00

