FuzzyMatchMaker
--------------

The FuzzyMatchMaker is a record linkage tool implementing a novel scorecard algorithm for matching records from different datasets. It's implementation in the Julia programming language is built for speed and simplicity.

The package can be downloaded and installed from within Julia by running:
```julia
Pkg.clone("https://github.com/karbarcca/FuzzyMatchMaker.git")
```


Usage is extremely simple. Read your datasets in by whatever means you perfer (we suggest [`readcsv`](http://docs.julialang.org/en/latest/stdlib/base/#Base.readcsv)). Once your data is read in, you may also build an array of stopwords, as well as a Dict mapping words to replacements (e.g. Bob => Robert). A full exmample of using would be:
```julia
src = readcsv("source.csv",String)
mat = readcsv("tomatch.csv",String)
stopwords = ["ST","AVE","RD","DR","STE","BLVD","LN"]
replacements =  (ASCIIString=>ASCIIString)["ABBY"=>"ABBIE","ABIGAIL"=>"ABBIE",...
@time catalog = buildcatalog(src,stopwords,repl); # can be extremely large, recommend suppressing output
@time t = fuzzymatch(catalog,mat,5,ones(size(mat)[2]),stopwords,repl)
```
Note that a catalog is built from the source data first and then passed into the `fuzzymatch` function for generating matches for the `mat` dataset. This ensures efficiency if there are multiple datasets to be matched against a master set.

The function signatures of `buildcatalog` and `fuzzymatch` are:
```julia
buildcatalog(src::Array{String,2}, # master data source
             stopwords=ASCIIString[], # words to ignore
             repl=Dict{ASCIIString,ASCIIString}()) # a Dict mapping words to their replacements in processing
             
fuzzymatch(catalog::Catalog, # return value from buildcatalog function
           mat::Array{String,2}, # dataset to match against master
           num_matches=5, # the number of matches to return
           weights=ones(size(mat)[2]), # weights of the columns in matching
           stopwords=String[], # a list of words that should be ignored
           repl=Dict{String,String}()) # a Dict mapping words to their replacements in processing
```
The return value of the `fuzzymatch` function is a DataFrame (i.e. a table of data) listing the `mat` rows with the corresponding matches (the exact # is user-defined) in subsequent columns with the match scores.

Feel free to open an issue for any bugs or suggestions. Thanks!
