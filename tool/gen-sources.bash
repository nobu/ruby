#!/bin/bash
set -e

nop=
dump_ast=
traps=0

opt= optarg=
while getopts cd:kn-: opt; do
    optarg="$OPTARG"
    if [[ "$opt" = - ]]; then
        opt="-${optarg%%=*}"
        if [[ "$optarg" = *=* ]]; then optarg="${optarg#*=}";
        elif optarg="${!OPTIND}"; [[ "${optarg}" = -* ]]; then optarg=
        else shift; fi
    fi

    case "-$opt" in
        -c|--clean) nop=:;;
        -n|--dry-run) nop=echo;;
        -d|--dump[-_]ast) dump_ast="$optarg" RUBY_DUMP_AST=;;
        -k|--keep) trap=;;
        --) break;;
        -*) echo "${0##*/}: Unknown option $1" 1>&2; exit 1;;
    esac
done
shift $((OPTIND-1))

if tooldir="${0%/*}"; [ "$tooldir" = "$0" ]; then
    tooldir=. srcdir=..
elif srcdir="${tooldir%/*}"; [ "$srcdir" = "$tooldir" ]; then
    srcdir=.
fi
template="${srcdir}/template"

[ "$nop" = echo ] || trap 'rm -fr "${clean[@]}"' $trap 2

for t in config.status .rbconfig.time Makefile GNUmakefile; do
    [ -z "${nop}" -a -e "$t" ] && echo "exist: $t" && exit 1
done

${nop} cp -i tool/prereq.status config.status < /dev/null
${nop} cp -i /dev/null .rbconfig.time < /dev/null
clean=(config.status .rbconfig.time)
for mk in Makefile GNUmakefile; do
    [ ${nop} ] || sed -f "$tooldir/prereq.status" "$template/$mk.in" > $mk
    clean+=("$mk")
done
clean+=(prism/.time prism/util/.time build-tool)
${nop} make "HAVE_BASERUBY=yes" "BASERUBY=${RUBY-ruby}" \
       ${RUBY_DUMP_AST:+"DUMP_AST=$RUBY_DUMP_AST" "DUMP_AST_TARGET=no"} \
       "${@-prereq}"
[ -z "$dump_ast" ] || ${nop} cp build-tool/dump_ast "$dump_ast"
${nop} rm -fr "${clean[@]}"
