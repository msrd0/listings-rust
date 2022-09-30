#!/bin/bash
set -euo pipefail

# download a search index
function download() {
	local url js json
	url="$1"
	json="$2"
	js=$(mktemp --suffix=.js)

	if [ ! -e $json ]
	then
		echo "Downloading $url ..."
		echo 'var window = {};' >$js
		wget -q --show-progress -O- "$url" >>$js
		echo 'console.log(JSON.stringify(searchIndex));' >>$js
		node $js >$json
		rm $js
	fi
}

# extract a certain type from a certain crate
# type values: https://github.com/blackgear/rustdoc_seeker/blob/master/src/seeker.rs#L60
function extract() {
	local json crate ty suffix
	json="$1"
	crate="$2"
	ty="$3"
	suffix="${4:-}"

	filter=
	for key in $(jq ".$crate.t | to_entries | .[] | select(.value == $ty) | .key" $json)
	do
		if [ -n "$filter" ]
		then
			filter="$filter or "
		fi
		filter="$filter.key == $key"
	done
	if [ -n "$filter" ]
	then
		jq -r ".$crate.n | to_entries | .[] | select($filter) | .value" $json \
			| sed -z "s|\n|$suffix, |g;s|, \$|\n|"
	fi
}

# extract all
function extract_all() {
	local json crate
	json="$1"
	crate="$2"

	echo '  % traits'
	echo "  morekeywords = [2]{$(extract $json $crate 8)},"
	echo '  % primitives'
	echo "  morekeywords = [3]{$(extract $json $crate 15)},"
	echo '  % structs'
	echo "  morekeywords = [4]{$(extract $json $crate 3)},"
	echo '  % enums'
	echo "  morekeywords = [4]{$(extract $json $crate 4)},"
	echo '  % typedefs'
	echo "  morekeywords = [4]{$(extract $json $crate 6)},"
	echo '  % unions'
	echo "  morekeywords = [4]{$(extract $json $crate 19)},"
	echo '  % macros'
	echo "  morekeywords = [5]{$(extract $json $crate 14 '!')},"
}

rustver="1.64.0"
download "https://doc.rust-lang.org/stable/search-index$rustver.js" rust.json

indexmapver="1.9.1"
download "https://docs.rs/indexmap/$indexmapver/search-index-20220620-1.63.0-nightly-5750a6aa2.js" indexmap.json

logver="0.4.17"
download "https://docs.rs/log/$logver/search-index-20220501-1.62.0-nightly-4dd8b420c.js" log.json

numintver="0.1.45"
download "https://docs.rs/num-integer/$numintver/search-index-20220429-1.62.0-nightly-a707f4010.js" numint.json

pastever="1.0.9"
download "https://docs.rs/paste/$pastever/search-index-20220830-1.65.0-nightly-02654a084.js" paste.json

randver="0.8.5"
download "https://docs.rs/rand/$randver/search-index-20220213-1.60.0-nightly-1e12aef3f.js" rand.json

rayonver="1.5.3"
download "https://docs.rs/rayon/$rayonver/search-index-20220512-1.62.0-nightly-a5ad0d29a.js" rayon.json

# prepare file
echo '\NeedsTeXFormat{LaTeX2e}[1994/06/01]' >listings-rust.sty
echo '\ProvidesPackage{listings-rust}[2022/09/21 Custom Package]' >>listings-rust.sty
echo >>listings-rust.sty
echo '\RequirePackage{color}' >>listings-rust.sty
echo '\RequirePackage{listings}' >>listings-rust.sty
echo >>listings-rust.sty
echo '\lstdefinelanguage{Rust}{' >>listings-rust.sty
echo '  morecomment = [l]{//},' >>listings-rust.sty
echo '  morecomment = [s]{/*}{*/},' >>listings-rust.sty
echo '  morestring = [b]{"},' >>listings-rust.sty
echo "  morestring = [b]{'}," >>listings-rust.sty 
echo '  alsoletter = {!},' >>listings-rust.sty
echo "  % %%% Rust $rustver Standard Library" >>listings-rust.sty
echo '  % keywords' >>listings-rust.sty
echo "  morekeywords = {$(extract rust.json std 21)}," >>listings-rust.sty
echo "  morekeywords = [5]{macro_rules!}," >>listings-rust.sty 
extract_all rust.json std >>listings-rust.sty
echo "  % %%% Rust $rustver proc-macro" >>listings-rust.sty
extract_all rust.json proc_macro >>listings-rust.sty 
echo "  % %%% indexmap $indexmapver" >>listings-rust.sty
extract_all indexmap.json indexmap >>listings-rust.sty
echo "  % %%% log $logver" >>listings-rust.sty
extract_all log.json log >>listings-rust.sty
echo "  % %%% num-integer $numintver" >>listings-rust.sty
extract_all numint.json num_integer >>listings-rust.sty
echo "  % %%% paste $pastever" >>listings-rust.sty
extract_all paste.json paste >>listings-rust.sty
echo "  % %%% rand $randver" >>listings-rust.sty
extract_all rand.json rand >>listings-rust.sty
echo "  % %%% rayon $rayonver" >>listings-rust.sty
extract_all rayon.json rayon >>listings-rust.sty
echo '}' >>listings-rust.sty
