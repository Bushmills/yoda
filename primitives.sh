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

atom["dup"]='s+=("s[-1]")'                # push_s1
atom["over"]='s+=("s[-2]")'               # push_s2
atom["pluck"]='s+=("s[-3]")'              # push_s3
atom["drop"]='unset "s[-1]"'              # pop
atom["@"]='s[-1]="m[s[-1]]"'              # s1=(s1)
atom["1+"]='((s[-1]++))'                  # s1++
atom["1-"]='((s[-1]--))'                  # s1--
atom["2*"]='((s[-1]*=2))'
atom["2/"]='((s[-1]/=2))'
atom["s1=tmp"]='s[-1]="$tmp"'
atom["s2=tmp"]='s[-2]="$tmp"'
atom["s3=tmp"]='s[-3]="$tmp"'
atom["s4=tmp"]='s[-4]="$tmp"'
atom["tmp=s1"]='tmp=${s[-1]}'
atom["tmp=s2"]='tmp=${s[-2]}'
atom["tmp=s3"]='tmp=${s[-3]}'
atom["tmp=s4"]='tmp=${s[-4]}'
atom["s1=s2"]='s[-1]=${s[-2]}'
atom["s1=s3"]='s[-1]=${s[-3]}'
atom["s2=s1"]='s[-2]=${s[-1]}'
atom["s2=s3"]='s[-2]=${s[-3]}'
atom["s3=s1"]='s[-3]=${s[-1]}'
atom["s3=s2"]='s[-3]=${s[-2]}'
atom["s4=s2"]='s[-4]=${s[-2]}'
atom["s4=s2"]='s[-4]=${s[-2]}'
atom["r@"]='s+=("r[-1]")'
atom['rpush']='r+=("s[-1]")'              # s1 -> r++
atom['rdrop']='unset "r[-1]"'             # --r
atom["rpop"]='unset "r[-1]"'              # --r
atom["allot"]='((dp+=s[-1]))'

# ----- colon/semicolon --------------------- #fold00

semicolon()  {
   compile   																         # compilation is gathered in an array body. Only
   compiling=0				   											         # when semicolon completes compilation, is
   derestrict
# not good resolving here: when fwd ref will be resolved in same
# source file, each semicolon will unnecessarily read postlib.
#  resolve
}																				         # a function created from contents of array.

colon ';'      # semicolon
   code "(( s[-1] == $magic )) || unstructured ':'"	               # check the magic left by :
	atom 'drop'
	code '(( ${s[-1]} == ${#body[@]} )) && code ":"'			         # insert a noop into empty function bodies
	atom 'drop'
   code 'semicolon'														         # compile $lastword from $body[@], resume interpreting
semicolon
compileonly

colon ':'      # colon
   code 'word'																		   # parse space delimited word from input stream
   code 'colon "$word"'															   # generate synthetic name, associate with word
	code "s+=(\"\${#body[@]}\" \"$magic\")"                           # allow check of structure and empty function
   code 'compiling=1'
semicolon
interpretonly

colon 'u:'      # ucolon
   code 'word'																		   # parse space delimited word from input stream
   code '[[ -z "${headersunresolved["$word"]}" ]] && restrict || colon "$word"'
	code "s+=(\"\${#body[@]}\" \"$magic\")"                           # allow check of structure and empty function
   code 'compiling=1'
semicolon
interpretonly


# ----- diagnostics ------------------------- #FOLD00

words()	{
   local headers
   for tmp in ${headerslistlist[@]}; do
      declare -n headers="$tmp"
      printf '%s\n' "--- ${tmp#"headers"} ---"
	   printf  "%s " "${!headers[@]}"
      printf '\n\n'
   done
}

crossref()  {
   local headers
   for tmp in ${headerslistlist[@]} headersunresolved; do
      declare -n headers="$tmp"
      (( ${#headers[@]} )) && {
         printf '%s:\n' "${tmp#"headers"}"
         for tmp2 in "${!headers[@]}"; do
	         printf  "    %-16s %s\n" "${headers["$tmp2"]}" "$tmp2"
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

# debug only: add visibly comment to compiled functions
backslash() {
   code ": '$*'"
}

# compile an echo statement into the word to debug
# when that word executes, the text argument is printed
debugecho()  { code "echo '--- $*'"; }
debug()      { debugecho "$@"; }


colon '.s'
   code '((${#s[@]}))&&printf "%s " "${s[@]}"'
semicolon
inline



# ----- does> ------------------------------- #fold00
#  : myarray  create allot does> + ;
#  10 myarray foo
#  5 foo .
#
#  defining word:  myarray
#  defined word:   foo
#
colon 'dodoes'
	code 'echo "executing dodoes, ref=arg1"'
semicolon

colon 'does>'
   backslash 'this is does>'
   debug 'executing does'
   backslash 'compiling dodoes to end of defining word'
	code "code \"${headers[dodoes]}\" \"1234\""
   backslash 'compiling defining word now'
   code "compile"
  backslash 'compiling defining word finished'

# compile following code into
#   code 'word'
#   backslash 'compile this to
   backslash 'following is run time code for defined word'
   backslash 'must be inlined or called from defined word, with data address already on stack'
   backslash 'create a new word for run time part'
   code "create \"bla\"   \"does\""
   code 'inline'
   code 'echo "--- will now compile run time part of defined word"'
# ;  will compile previous code to last header

semicolon
compileonly



# ----- defining words ---------------------- #fold00

# actually works: defining word builder
data()  {
   word																		         # parse name of new word
   create "$word" 										                     # create header. no header prefix passed - will get overwritten anyway.
   headers["$word"]="s+=(${s[-1]})"							               # replace name with code :)
   unset "s[-1]"															         # replaced code pushes this to stack
}
# this bit about "replacing name with code" may be confusing. it is. what
# happens there is:
# "name" is, in case of headers, a function name. when compiling, name gets
# simply written to a new function, and is called when that function is executed.
# During interpretation, the name is also simply executed, resulting in calling
# the function.
# Therefore can the name be replaced by code, which will the, during
# compilation, get compiled to new functions, instead of the former, now
# overwritten, name. Very similar at interpret time.
# One gotcha was that instead of passing the command string for immediate
# execution to interpreter, an "eval" statement was needed there.
# That eval has been added to yoda() function, in the execute branch.

colon 'create'
   code 's+=("$dp")'
	code 'data'
semicolon

colon 'variable'
   code 's+=("dp++")'
	code 'data'
semicolon

colon 'constant'
	code 'data'
semicolon


# arrays compile to rather good code, actually. This may look more
# complex than needed. but this compile time only.
# actually generated code in a function is something like:
#     ((s[-1]+="50"));   # adds array base address to item index
colon "array"
	code 'word'                                                       # parse array name
   code "create \"\$word\""                                          # no header prefix passed - will get overwritten in next step anyway
   code 'headers["$word"]="((s[-1]+=\"$dp\"))"'                      # rewrite
   atom 'allot'
   atom 'drop'
semicolon

# could possibly be faded out. in favour of context vocs
colon 'immediate'
   code 'immediate'
semicolon

# ----- compiler and word search related ---- #FOLD00

# ( -- 0 | a )
exists() {
   local headers                                                     # meant to spare me from saving and restoring vectored headers variable
   word
   for tmp in "${headerslistlist[@]}"; do                            # loop through all vocs we want to search
      declare -n headers="$tmp"                                      # vector headers to next vocabulary
      [[ -z "${headers["$word"]}" ]] || {                            # word in there?
         tmp="${headers["$word"]}"                                   #     yes: remember name
         [[ $tmp == ${header_code}* ]] || break                      # can not tick data
         s+=("${headers["$word"]#"${header_code}_"}")                # convert name to "address" and push
         return 0                                                    # found word, stacked execution token
      }
   done                                                              # go on search next voc
   s+=("0")
}


tick()  {
   local headers                                                     # meant to spare me from saving and restoring vectored headers variable
   exists || error "can't tick data"
   (( s[-1] )) || notfound "$word"                                   # none left -> all searched, but not found.
}

# NOTE: tick and execute need names to look like foobar_4711
colon "'"
   code 'tick'
semicolon

colon "[']"
   code 'tick'
   code 'code "s+=(${s-1})"'
   atom 'drop'
semicolon
compileonly

colon '['
   code 'restricted||compiling=0'                                    # don't allow to suspend compilation when compilation is muted
semicolon                                                            # consequence of above is that any compileonly word which modifies stack if not paired
compileonly                                                          # must be forbidden to so so by checking restricted state, literal is an example for such a word.

colon ']'
   code 'compiling=1'
semicolon

colon 'literal'
   code 'restricted || { code "s+=(\"${s[-1]}\")"; unset "s[-1]"; }'
semicolon
compileonly

colon 'execute'
   atom 'tmp=s1'
   atom 'drop'
   code "${header_code}_\${tmp}"
semicolon



# ----- misc -------------------------------- #fold00

colon 'noop'
	code ':'
semicolon
inline

colon "\\"	  					                                          # double quoted escaped backslash rather than
   code 'line=""'				                                          # single quoted single backslash because
semicolon						                                          # efte syntax highlighting gets confused
immediate

colon '('
	code "parse ')'"
semicolon
immediate

# ----- parameter stack --------------------- #fold00

colon 'depth'
	code 's+=("${#s[@]}")'
semicolon
inline

colon 'dup'
	atom 'dup'
semicolon
inline

colon '?dup'
	code '((s[-1])) &&'
	atom 'dup'
semicolon
inline

colon 'drop'
   atom 'drop'
semicolon
inline

colon 'over'
	atom 'over'
semicolon
inline

colon 'pluck'
	atom 'pluck'
semicolon
inline

colon 'pick'
	code '((s[-1]=s[-(s[-1]+2)]))'
semicolon
inline

colon '2dup'
	atom 'over'
	atom 'over'
semicolon
inline

colon '2drop'
   atom 'drop'
   atom 'drop'
semicolon
inline

colon 'swap'
   atom 'tmp=s2'
   atom 's2=s1'
   atom 's1=tmp'
semicolon
inline

colon '2swap'
   atom 'tmp=s4'
   atom 's4=s2'
   atom 's2=tmp'
   atom 'tmp=s3'
   atom 's3=s1'
   atom 's1=tmp'
semicolon
inline

colon 'nip'
   atom 's2=s1'
   atom 'drop'
semicolon
inline

colon 'tuck'
   atom 'dup'
   atom 's2=s3'
   atom 's3=s1'
semicolon
inline

colon 'rot'
   atom 'tmp=s1'
   atom 's1=s3'
   atom 's3=s2'
   atom 's2=tmp'
semicolon
inline

colon '-rot'
   atom 'tmp=s1'
   atom 's1=s2'
   atom 's2=s3'
   atom 's3=tmp'
semicolon
inline

# ----- return stack ------------------------ #fold00

colon 'rdepth'
	code 's+=("${#r[@]}")'
semicolon
inline

colon 'r@'
	atom 'r@'
semicolon
inline

colon 'rdrop'
	atom 'rdrop'
semicolon
inline

colon '>r'
	atom 'rpush'
   atom 'drop'
semicolon
inline

colon 'r>'
	atom 'r@'
	atom 'rdrop'
semicolon
inline

# ----- string stack ------------------------ #fold00
# left$ right$ mid$

colon 'depth$'
	code 's+=("${#ss[@]}")'
semicolon
inline

colon 'empty$'
   code 'ss=()'
semicolon
inline

colon 'dup$'
	code 'ss+=( "${ss[-1]}" )'
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
	code 'ss+=("${ss[-s[-1]-1]}")'
   atom 'drop'
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

# -leading$:  ${myVar##*( )}
# -trailing$: ${myVar%%*( )}

colon '.ss'
   code '(( ${#ss[@]} )) &&'
   code 'printf "\"%s\" " "${ss[@]}"'
semicolon

colon 'type$'
   code 'printf "%s" "${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon
inline

colon 'count$'
   code 's+=("${#ss[-1]}")'
   code 'unset "ss[-1]"'
semicolon
inline

# split string into single words at white space, return count of resulting single word strings.
# ( -- u )   ss: ( $ -- $1 $2 $3 §.. $u )
colon 'chop$'
   code 'tmp="${ss[-1]}"'
   code 'unset "ss[-1]"'
   code 's+=("-${#ss[@]}")'
	code 'ss+=($tmp)'
   code '((s += ${#ss[@]} ))'
semicolon

# ---------- command ---------      - output -        ----- mnemonic -----
# "abcdefgh"   2 left$   type$      ab                "keep 2 left"
# "abcdefgh"  -2 left$   type$      abcdef            "keep left all but last 2"
# "abcdefgh"   2 right$  type$      gh                "keep 2 right"
# "abcdefgh"  -2 right$  type$      cdefgh            "keep right all but first 2"
# "abcdefgh"   2 split$  type$      ab cdefgh         "split at left"
# "abcdefgh"  -2 split$  type$      abcdef gh         "split at right"

colon 'left$'
   code 'ss[-1]=${ss[-1]:0:s[-1]}'
   atom 'drop'
semicolon

colon 'right$'
   code 'ss[-1]=${ss[-1]:0-s[-1]}'
   atom 'drop'
semicolon

colon 'mid$'
   code 'ss[-1]=${ss[-1]:s[-2]:s[-1]}'
   atom 'drop'
   atom 'drop'
semicolon

colon 'split$'
   code 'ss+=("${ss[-1]:s[-1]}")'
   code 'ss[-2]="${ss[-2]:0:s[-1]}"'
   atom 'drop'
semicolon

colon 'join$'
   code 'ss[-2]+="${ss[-1]}"'
   code 'unset "ss[-1]"'
semicolon

colon '$='
   code '[[ ${ss[-1]} != ${ss[-2]} ]];s+=("-$?")'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

colon '$<'
   code '[[ ${ss[-1]} > ${ss[-2]} ]];s+=($(($?-1)))'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

colon '$>'
   code '[[ ${ss[-1]} < ${ss[-2]} ]];s+=($(($?-1)))'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

# "nice"    "this is a very *** foo"   "***" replace$    ->   "this is a very nice foo"
# "nope"    "this is a very *** foo"   "?" replace$      ->   "this is a very *** foo"

asc()  {
   if [[ -z "${ss[-1]}" ]]; then
      s+=("0")
   else
      s+=("${asc[${ss[-1]:0:1}]}")
      ss[-1]="${ss[-1]:1}"
   fi
}

colon 'asc'
   code 'asc'
semicolon

colon 'char$'
   code 'ss+=("${char[s[-1]]}")'
   atom 'drop'
semicolon

# $ -> a -- n
unpackstring()  {
   string="${ss[-1]}"
   tmp="${#string}"
   unset "ss[-1]"
   for ((len=0; tmp--; len++)); do
      m[s[-1]++]="${asc[${string:len:1}]}"
   done
   s[-1]="$len"
}
colon 'unpack$'
   code 'unpackstring'
semicolon

# a n -- -> $
packstring()  {
   ss+=("")
   for ((; s[-1]--; )); do
      ss[-1]+="${asc[m[s[-2]++]]}"
   done
   unset "s[-1]"
   unset "s[-1]"
}
colon 'pack$'
   code 'packstring'
semicolon

# should there be a string holding second stack,
# allowing to temporarily move strings out of the way?

# ----- bit logic --------------------------- #fold00

colon 'and'
	code '((s[-2] &= s[-1]))'
   atom 'drop'
semicolon
inline

colon 'or'
	code '((s[-2] |= s[-1]))'
   atom 'drop'
semicolon
inline

colon 'xor'
	code '((s[-2] ^= s[-1]))'
   atom 'drop'
semicolon
inline

colon 'invert'
	code '((s[-1] ^= -1))'
semicolon
inline

colon lshift
   code '((s[-2] <<= s[-1]))'
   atom 'drop'
semicolon
inline

colon rshift
   code '((s[-2] >>= s[-1]))'
   atom 'drop'
semicolon
inline

# ----- comparison -------------------------- #fold00

((unsigned)) || {

colon '0='
	code '((s[-1] = -(! s[-1])))'
semicolon
inline

colon '0<'
	code '((s[-1] = (! (s[-1] & msb))-1))'
semicolon
inline

colon '='
	code '((s[-2] = -(s[-2] == s[-1])))'
   atom 'drop'
semicolon
inline

colon '<>'
	code '((s[-2] = -(s[-2] != s[-1])))'
   atom 'drop'
semicolon
inline

#colon 'u<'
#	code '((s[-2] = -((s[-2]&maxuint) < (s[-1]&maxuint))))'
#   code 'unset "s[-1]"'
#semicolon

#colon 'u>' # partially tested 16
#	code '((s[-2] = -((s[-2]&maxuint) > (s[-1]&maxuint))))'
#   code 'unset "s[-1]"'
#semicolon

colon '<'
	code '((s[-2] = -(s[-2] < s[-1])))'
   atom 'drop'
semicolon
inline

# broken
colon '>'
	code '((s[-2] = -(s[-2] > s[-1])))'
   atom 'drop'
semicolon
inline
}


((unsigned)) && {

colon '0='  # tested 16
	code '((s[-1] = -(! (s[-1]&maxuint))))'
semicolon
inline

colon '0<'  # tested 16
	code '((s[-1] = (! (s[-1]&msb))-1))'
semicolon
inline

colon '='  # tested 16
	code '((s[-2] =  -(!((s[-2]^s[-1])&maxuint))))'
   atom 'drop'
semicolon

colon '<>'  # tested 16
	code '((s[-2] =  -((s[-2]^s[-1])&maxuint)))'
   atom 'drop'
semicolon

colon 'u<' # partially tested 16. maybe broken.
	code '((s[-2] = -((s[-2]&maxuint) < (s[-1]&maxuint))))'
   atom 'drop'
semicolon

colon 'u>' # partially tested 16
	code '((s[-2] = -((s[-2]&maxuint) > (s[-1]&maxuint))))'
   atom 'drop'
semicolon

colon '<' # broken
	code '((s[-2] = -(s[-2] < s[-1])))'
   atom 'drop'
semicolon

colon '>' # broken
	code '((s[-2] = -(s[-2] > s[-1])))'
   atom 'drop'
semicolon

}


# ----- arithmetics ------------------------- #fold00

colon maxuint                                                        # effectively a constant, but can't define them differently yet
   code "s+=(\"$maxuint\")"
semicolon
inline

colon maxint                                                         # effectively a constant, but can't define them differently yet
   code "s+=(\"$maxint\")"
semicolon
inline

colon msb                                                            # effectively a constant, but can't define them differently yet
   code "s+=(\"$msb\")"
semicolon
inline



colon '1+'
   atom '1+'
semicolon
inline

colon '1-'
   atom '1-'
semicolon
inline

colon '2*'
   atom '2*'
semicolon
inline

colon '2/'
   atom '2/'
semicolon
inline

colon 'cells'
   code ':'
semicolon
immediate

colon 'cell+'
   atom '1+'
semicolon
immediate
inline

colon '+'
	code '((s[-2]+="s[-1]"))'
   atom 'drop'
semicolon
inline

colon '-'
	code '((s[-2]-="s[-1]"))'
   atom 'drop'
semicolon
inline

colon '*'
	code '((s[-2]*="s[-1]"))'
   atom 'drop'
semicolon
inline

colon '/'
	code '((s[-2]/="s[-1]"))'
   atom 'drop'
semicolon
inline

colon 'mod'
	code '((s[-2]%="s[-1]"))'
   atom 'drop'
semicolon

colon 'negate'
   code '((s[-1] *= -1))'
semicolon
inline

#colon '?negate'
#   code '(( s[-1] && s[-2] *= -1))'
#   atom 'drop'
#semicolon
#inline


colon 'abs'
   code '((s[-1] *= (((0<s[-1])-1)|1)))'
semicolon
inline

colon '*/'
   code '(( s[-3] *= s[-2], s[-3] /= s[-1] ))'
   atom 'drop'
   atom 'drop'
semicolon

colon '/mod'		# x1 x2 -- rem quot
   code '(( tmp = s[-1], s[-1] = s[-2]/tmp, s[-2] = s[-2]%tmp ))'
semicolon
inline


# s3 s2 s1  -- s3*s2%s1 s3*s2/a1
colon '*/mod'
   code '(( tmp=s[-3]*s[-2], s[-3]=tmp%s[-1], s[-2]=tmp/s[-1] ))'
   atom 'drop'
semicolon


colon 'u/mod'		# u1 u2 -- rem quot
   code '(( tmp=s[-1]&maxuint, s[-1]=(s[-2]&maxuint)/tmp, s[-2]=(s[-2]&maxuint)%tmp ))'
semicolon
inline


# ----- memory ------------------------------ #fold00

colon '@'
   atom '@'
semicolon
inline

colon 'skim'
   code 's+=("m[s[-1]++]")'
semicolon
inline

colon 'count'
	code 's+=("m[s[-1]++] & 255")'
semicolon
inline

colon '!'
	code 'm[s[-1]]="s[-2]"'
   atom 'drop'
   atom 'drop'
semicolon
inline

colon '<-'  ä                    # swap !
	code 'm[s[-2]]="s[-1]"'
   atom 'drop'
   atom 'drop'
semicolon

colon '+!'
	code 'm[s[-1]]+="s[-2]"'
   atom 'drop'
   atom 'drop'
semicolon
inline

colon 'on'
	code 'm[s[-1]]="-1"'
   atom 'drop'
semicolon
inline

colon 'off'
	code 'm[s[-1]]="0"'
   atom 'drop'
semicolon
inline

colon 'exchange'
	code '((tmp=m[s[-1]]))'
   code '((m[s[-1]]=s[-2]))'
   atom 'drop'
   atom 's1=tmp'
semicolon

declare -i dp=0
colon 'here'
	code 's+=("$dp")'
semicolon
inline

colon 'allot'
	atom 'allot'
   atom 'drop'
semicolon
inline

colon ','
   code 'm[dp++]="${s[-1]}"'
   atom 'drop'
semicolon
inline

colon 'pad'
   code 's+=("dp+256")'
semicolon
inline


# ( a u c -- )
colon 'fill'
# c -> m[a++],  u times
   code 'for ((;s[-2]--;)); do'
   code '((m[s[-3]++] = s[-1]))'
   code 'done'
   atom 'drop'
   atom 'drop'
   atom 'drop'
semicolon

# ( a u -- )
colon 'erase'
# 0 -> m[a++],  u times
   code 'for ((;s[-1]--;)); do'
   code '((m[s[-2]++] = 0))'
   code 'done'
   atom 'drop'
   atom 'drop'
semicolon


# ( a1 a2 u -- )
colon 'move'
# m[a1++} -> m[a++],  u times
   code 'for ((;s[-1]--;)); do'
   code '((m[s[-2]++] = m[s[-3]++]))'
   code 'done'
   atom 'drop'
   atom 'drop'
   atom 'drop'
semicolon




# ----- flow control ------------------------ #fold00

remagic

colon 'if'
	code 'code "((tmp = s[-1]))"'                                     # can't use atoms here yet
	code 'code "unset \"s[-1]\""'
	code 'code "if ((tmp)); then"'
	code "s+=(\"\${#body[@]}\" \"$magic\")"                           # allow check of structure and empty function
semicolon
compileonly

colon 'else'
	code "(( s[-1]++ == \"$magic\" )) || unstructured 'if'"
	code '(( s[-2] == ${#body[@]} )) && code ":"'
   code 'code "else"'
	code 's[-2]="${#body[@]}"'
semicolon
compileonly

colon 'then'
	code "(( s[-1] == \"$magic\" ||  s[-1] == \"$((magic+1))\" )) || unstructured 'if or else'"
	atom 'drop'
	code '(( s[-1] == ${#body[@]} )) && code ":"'
	atom 'drop'
	code 'code "fi"'
semicolon
compileonly


remagic

colon 'begin'
	code 'code "while :; do"'
	code "s+=(\"\${#body[@]}\" \"$magic\")"                           # allow check of structure and empty function
semicolon
compileonly


colon 'again'
	code "(( s[-1] == \"$magic\" )) || unstructured 'begin'"
	atom 'drop'
	code '(( s[-1] == ${#body[@]} )) && code ":"'
	atom 'drop'
	code 'code "done"'
semicolon
compileonly

colon 'until'
	code "(( s[-1] == \"$magic\" )) || unstructured 'begin'"
	atom 'drop'
   code 'code "((s[-1]))&&break"'
	code 'code "unset \"s[-1]\""'
	atom 'drop'
   code 'code "done"'
	code 'code "unset \"s[-1]\""'
semicolon
compileonly

colon 'while'
	code "(( s[-1]++ == \"$magic\" )) || unstructured 'begin'"
   code 'code "((s[-1]))||break"'
	code 'code "unset \"s[-1]\""'
semicolon
compileonly

colon 'repeat'
	code "(( s[-1] == \"$((magic+1))\" )) || unstructured 'while'"
   atom 'drop'
   atom 'drop'
	code 'code "done"'
	code 'code "unset \"s[-1]\""'
semicolon
compileonly


remagic
colon 'for'
   code "code 'r+=(\"\$i\")'"
	code 'code "((i=s[-1]))"'
	code 'code "unset \"s[-1]\""'
	code 'code "for ((; i--; )); do"'
	code "s+=(\"\${#body[@]}\" \"$magic\")"                           # allow check of structure and empty function
semicolon
compileonly

colon 'i'
	code 's+=("i")'
semicolon
inline

colon 'j'
	atom 'r@'
semicolon
inline

colon 'next'
	code "((s[-1] == $magic))||unstructured 'for'"
	atom 'drop'
	code '((s[-1] == ${#body[@]})) && code ":"'
	atom 'drop'
	code 'code "done"'
   code "code 'i=\"\${r[-1]}\"'"
	code 'code "unset \"r[-1]\""'
semicolon
compileonly


remagic
dodo()  {
   r+=("$ibar")
   r+=("$i")
	((i=s[-1]))
	unset "s[-1]"
	((ibar=s[-1]))
	unset "s[-1]"
}

colon 'leave'
   code 'code "break"'
semicolon
compileonly

colon '?leave'
   code "code 'tmp=\"\${s[-1]}\"; unset \"s[-1]\"'"
   code 'code "((tmp))&&break"'
semicolon
compileonly

colon 'do'
   code 'code "dodo"'
	code 'code "while :;do"'
	code "s+=(\"$magic\")"                                            # allow check of structure and empty function
semicolon
compileonly

colon 'loop'
	code "((s[-1] == $magic))||unstructured 'do'"
	atom 'drop'
	code 'code "((++i < ibar))||break"'
   code 'code "done"'
   code "code 'i=\"\${r[-1]}\"'"
	code 'code "unset \"r[-1]\""'
   code "code 'ibar=\"\${r[-1]}\"'"
	code 'code "unset \"r[-1]\""'
semicolon
compileonly


colon '+loop'
	code "((s[-1] == $magic))||unstructured 'do'"
	atom 'drop'

   code 'code "((i+=(s[-1])))"'
	code 'code "unset \"s[-1]\""'
	code 'code "((i < ibar))||break"'
	code 'code "done"'

   code "code 'ibar=\"\${r[-1]}\"'"
	code 'code "unset \"r[-1]\""'
   code "code 'i=\"\${r[-1]}\"'"
	code 'code "unset \"r[-1]\""'
semicolon
compileonly


# compiled version: skip until end of word on false
colon 'lest'
   code 'code "tmp=\"\${s[-1]}\""'
	code 'code "unset \"s[-1]\""'
   code 'code "((tmp))||return" '
semicolon
compileonly    # compile only are inherently immediate

# interpreted version: skip rest of line when false
colon 'lest'
   code 'tmp="${s[-1]}"'
	code 'unset "s[-1]"'
   code '((tmp))||line=""'
semicolon
interpretonly

# compiled version: skip until end of word on true
colon 'unless'
   code 'code "tmp=\"\${s[-1]}\""'
	code 'code "unset \"s[-1]\""'
   code 'code "((tmp))&&return" '
semicolon
compileonly    # compile only are inherently immediate

# interpreted version: skip rest of line when true
colon 'unless'
   code 'tmp="${s[-1]}"'
	code 'unset "s[-1]"'
   code '((tmp))&&line=""'
semicolon
interpretonly

# evaluate input line unrtil end u times
colon 'times'
   code 'r+=(i)'
   code '((i=s[-1]))'
   atom 'drop'
   code 'while ((i--)); do evaluate "$line"; done'
   code '((i=r[-1]))'
   atom 'rdrop'
   code 'line=""'
semicolon
interpretonly

# this is the prefered version, repeating the line upon encountering many
# prefered because its use is more symmetrical with times, both specified
# before the repeated sequence.  times is harder to put at the end.
colon 'many'
   code 'until read -rsn1 -t 0.01; do evaluate "$line"; done'
   code 'line=""'
semicolon


# the alternative:  repeat line until a key is registered.
# rest of the line will be executed after key was tapped.
# sleep 1; clear; df; many
#colon 'many'
#   code 'read -rs -t 0.01 || line="$tib"'
#semicolon


colon 'bye'
   code 'exit'
semicolon


colon 'exit'
   code 'return'
semicolon
inline
compileonly


# ----- conditional compilation-------------- #FOLD00

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
   code 's+=( $(($?-1)) )'
semicolon

colon 'exists'
   code 'exists' || error "can't tick data"
semicolon

# ----- i/o --------------------------------- #fold00

colon 'ansi'
   code 'printf "\e[%sm" "${s[-1]}"'
   atom 'drop'
semicolon

# emit
colon 'emit'
   code 'printf "%c" "${char[s[-1]&255]}"'                            # given an ASCII, print the character
   atom 'drop'
semicolon
inline

colon 'parse$'
   code 'parse "${ss[-1]}"'
   code  'ss[-1]="$word"'
semicolon

colon 'parse'
   code 'parse "${char[s[-1]]}"'
   atom 'drop'
   code  'ss+=("$word")'
semicolon


keybuf=""
colon 'key'
   code 'if [[ -z "$keybuf" ]]; then'                                # key? may have put chars into keybuf
   code 'IFS="" read -rsn1 tmp'                                      # keybuf empty: read from console
   code 'keybuf+="${tmp}"'                                           # space if -z $tmp
   code 'fi'
   code 'tmp="${keybuf:0:1}"'                                        # read key from keybuf
   code 'tmp=$(printf "%d" '"\"'""\${tmp}\")"                        # treat ctrls as spaces, convert to ASCII
   code 's+=("$tmp")'                                                # push ASCII
   code 'keybuf="${keybuf:1}"'                                       # strip key from keybuf
semicolon

colon 'key?'
   code '[[ -z "$keybuf" ]] || { s+=("-1"); return; }'               # key in keybuf: yes, key waiting
   code 'IFS="" read -rsn1 -t0.01 tmp'                               # no key in keybuf: poll console
   code 's+=(-$((! $?)))'                                            # return value reflects key timeout condition
   code 'keybuf+="$tmp"'                                             # add key to buffer
semicolon

# read line into tib
# TODO: configurable ANSI sequences
query()  {
   printf '\e[3%sm' "$green"
	read -er -i "$keybuf" tib                                         # key? may have put chars into keybuf
   keybuf=""
   printf '\e[%sm' "$normal"
}
colon 'query'
   code 'query'
semicolon

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

colon 'bl'
   code 's+=("32")'
semicolon
inline

colon 'space'
	code 'printf " "'
semicolon
inline

colon 'spaces'
   code 'for ((tmp=s[-1]; tmp; tmp--)); do'
	code 'printf " "'
	code 'done'
   atom 'drop'
semicolon

colon 'page'
   code 'clear'
semicolon
inline

prompt()  {
   if ((compiling)); then
     	printf "|%-4s" ""                                              # just a vertical bar, then indenting, while compiling
   else
 		printf " %s" "ok"                                              # ok prompt
      ((${#s[@]})) &&  {                                             # stack depth > 0?
         tmp=".........+"                                            # yes: print a dot for each item
	      printf " %s" "${tmp:0:${#s[@]}}"                            # but not more than in $tmp
      }
      ((${#headersunresolved[@]})) &&  {                             # unresolved words > 0?
	      printf " (%d)" "${#headersunresolved[@]}"                   # yes: show count
      }
 		printf "\n"                                                    # finalize with linefeed
   fi
}

colon 'prompt'
    code 'prompt'
semicolon
inline

include()  {
   local dir file already
   [[ $1 = */* ]] && {                                               # slash in file spec -> don't search
      [[ -f "$1" ]] && {
         from "$1"                                                   # include with given path, allow multiple includes
         return 0                                                    # file found
      }
      return 1                                                       # not found error
   }
   for dir in "${libdirs[@]}"; do                                    # basename file -> search through lib dirs
      file="$dir/$1"                                                 # search through lib dirs for file
      [[ -f "$file" ]] && {                                          # file found: check if it's already included
         for already in "${files[@]}"; do
            [[ "$already" == "$file" ]] && {
               echo "not including $file again"
               file=""                                               # signal to outside loop that we're not interested in found file
               break
            }
         done
         [[ -z "$file" ]] || {
            trace "loading from $file"
            from "$file"                                             # load if found and not yet included
            return 0                                                 # first time load
         }
         return 0                                                    # alrady loaded
      }
   done
   return 1                                                          # file not found
}

colon 'from'
   code 'word'
   code 'include $word || filenotfound "$word"'
semicolon

colon '#files'
   code 's+=("${#files[@]}")'
semicolon
inline

colon 'files'
   code 'printf "%s\n"  "${files[@]}"|nl'                            # show list of already included files
semicolon

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
      name="$worddoc:$word"
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

doc()       {
   name="$worddoc:$1"
   editor "$name"
}
colon 'doc'
   code 'word'
   code 'doc "$word"'
semicolon

# topics
# n topic

colon 'topics'
   code 'printf "%s\n" "$topicdoc"/* | sed "s/.*\///" | nl'
semicolon

# ( u -- )
colon 'topic'
   code '((s[-1])) && { topics=("$topicdoc"/*); editor "${topics[s[-1]-1]}"; }'
   atom 'drop'
semicolon

helptext() {
cat << EOT
   Information is available on selected topics.
   To see a list of topics, execute:      topics
   to read about first topic, execute:    1 topic
   Any other listed topic can be opened
   by using the number next to it,
   in place for 1

   A list of included source files can be
   shown by executing:                    files
   These too are numbered. Use that
   number with commands like list and
   edit:                                  1 list
                                          2 edit
   "edit" assumes that yoda knows how to
   open a properly working editor on your
   system. Read topic "configuration" to
   find out how to set up yoda to use
   your preferred editor.

   A list of words understood by yoda
   can be seen by executing:              words
   Another list shows when entering:      crossref

   Documentation about those words can
   be opened by executing:                doc name
   where "name" is the name of the word
   you want information about.
EOT
}
colon 'help'
   code 'helptext'
semicolon



# ----- convenience ------------------------- #fold00
# TODO: optimiser: invalidate all stack register contents
colon 'empty'
   code 's=()'
semicolon
inline

# empty stack and string stack
# since warm doesn't empty them any longer, a convenient
# way to do so manually was needed.
colon '_'
   code 's=()'
   code 'ss=()'
semicolon
inline

colon 'secs'
	code 'sleep "${s[-1]}"'
   atom 'drop'
semicolon
inline

colon 'words'
   code "words"
semicolon

colon 'edit'
   code '((s[-1]))&&editor "${files[s[-1]-1]}"'
   atom 'drop'
semicolon

colon 'list'
   code '((s[-1]))&&cat "${files[s[-1]-1]}"'
   atom 'drop'
semicolon


# ----- experimental ------------------------ #fold00

# ----- unsorted ---------------------------- #fold00

# TODO: take recently introduced warmvector into consideration
colon 'warm'
   code 'warm'
semicolon

colon 'boot'
   code 'word'
   code 'need "$word"'                                               # cold entry may come from postlib
   code 'resolve'                                                    # in which case we want it now
   code 'coldvector="${headersstateless["$word"]}"'                  # because writing it to cold start vector
semicolon                                                            # this way cold start entry points can be forward referenced

# set header flag for inline compilation, can be used after a colon definition
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
   code 's+=( $((${#headersunresolved[@]})) )'
semicolon
inline

# read number from environment variable with name on string stack
# ( -- x )  ( string:  $1 -- )
colon 'env'
   code 's+=("${!ss[-1]}")'
semicolon
inline

# store $1 in bash environment variable with name $2
# ( x -- ) ( string:  $1-- )
colon '>env'
   code 'eval "${ss[-1]}=${s[-1]}"'
   code 'unset "ss[-1]"'
   atom 'drop'
semicolon


# read string from environment variable with name on string stack
# ( string:  $1 -- $2 )
colon 'env$'
   code 'ss[-1]="${!ss[-1]}"'
semicolon
inline

# store string $1 in bash environment variable with name $2
# ( string:  $1 $2 -- )
colon '>env$'
   code 'eval "${ss[-1]}=${ss[-2]}"'
   code 'unset "ss[-1]"'
   code 'unset "ss[-1]"'
semicolon

# convert a string representation of a number
# or arithmetic expression to an integer
# doesn't obey base
# ( -- x ) (string: $1 -- )
colon 'convert$'
   code '((s += ( 10#${ss[-1]} ) ))'
   code 'unset "ss[-1]"'
semicolon
inline

# convert a number to string
# doesn't obey base
# ( x -- ) (string: -- $1 )
colon 'convert'
   code 'ss+=("${s[-1]}")'
   atom 'drop'
semicolon
inline

# ( err -- )
colon 'abort'
   code 'abort "${s[-1]}"'
   atom 'drop'
semicolon

# ( f err -- )
colon '?abort'
   code '((s[-2]))&&abort "${s[-1]}"'
   atom 'drop'
   atom 'drop'
semicolon

# use recurse instead of word name to recurse into, as being
# able to refer to itself by name in a definition is due to change.
colon 'recurse'
   code 'code "${headersstateless["$lastword"]}"'
semicolon
compileonly
