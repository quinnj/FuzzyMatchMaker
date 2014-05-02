module FuzzyMatchMaker

export buildcatalog, fuzzymatch

using DataFrames
using ArrayViews
#TODO
 #Make sure stopwords/null work
 #Scoring
  #Use weights
  #pScore
  #Number of common words
  #Longest common substring
  #Levenshtein distance
type Catalog
    index::Dict{ASCIIString,Set{ASCIIString}}
    source::Dict{ASCIIString,Array{ASCIIString,1}}
    Catalog() = new(Dict{ASCIIString,Set{ASCIIString}}(),Dict{ASCIIString,Array{ASCIIString,1}}())
end

function buildcatalog(src,stopwords=ASCIIString[],repl=Dict{ASCIIString,ASCIIString}())
    catalog = Catalog()
    stops = Set(stopwords)
    srcids = src[:,1]
    src = src[:,2:end]
    srows,scols = size(src)
    sizehint(catalog.index,srows*scols)
    sizehint(catalog.source,srows)
    for i = 1:srows
        catalog.source[srcids[i]] = Array(ASCIIString,scols)
        for j = 1:scols
            f = get(repl,src[i,j],src[i,j])
            if !(f in stops)
                catalog.index[f] = push!(get(catalog.index,f,Set{ASCIIString}()),srcids[i])
                catalog.source[srcids[i]][j] = f
            else
                catalog.source[srcids[i]][j] = ""
            end
        end
    end
    return catalog
end
function fuzzymatch(catalog,
                    mat,
                    num_matches=5,
                    weights=ones(size(mat)[2]),
                    stopwords=String[],
                    repl=Dict{String,String}())
    stops = Set(stopwords)
    #preprocess
    matids = mat[:,1]
    mat = mat[:,2:end]
    mrows,mcols = size(mat)
    #matching
    results = cell(mrows,2+3*num_matches)
    for i = 1:mrows
        potentials = Set{ASCIIString}()
        sizehint(potentials,256)
        for j = 1:mcols
            word = uppercase(get(repl,mat[i,j],mat[i,j]))
            if !(word in stops)
                #expensive
                union!(potentials,get(catalog.index,word,Set{ASCIIString}()))
            end
        end
        indices = Array(ASCIIString,length(potentials))
        scores = zeros(length(potentials))
        mview = view(mat,i,1:mcols)
        for (ind,potmat) in enumerate(potentials)
            score = matchquality(catalog.source[potmat],mview,weights)
            indices[ind] = potmat
            scores[ind] = score
        end
        results[i,1] = matids[i]
        results[i,2] = mview
        sorts = sortperm(scores;rev=true)
        m = 1
        for j = 3:3:(2+3*num_matches)
            if m > endof(indices)
                results[i,j]   = ""
                results[i,j+1] = ""
                results[i,j+2] = NaN
            else
                results[i,j]   = indices[sorts[m]]
                results[i,j+1] = catalog.source[indices[sorts[m]]]
                results[i,j+2] = scores[sorts[m]]
            end
            m += 1
        end
    end
    names = Array(Symbol,size(results)[2])
    names[1] = :SOURCE_ID
    names[2] = :SOURCE_FIELDS
    i = 1
    for j = 3:3:(2+3*num_matches)
        names[j] = symbol("MATCH_"*string(i)*"_ID")
        names[j+1] = symbol("MATCH_"*string(i)*"_FIELDS")
        names[j+2] = symbol("MATCH_"*string(i)*"_SCORE")
        i += 1
    end
    results = {DataArray(results[:,col]) for col in 1:size(results)[2]}
    return DataFrame(results,DataFrames.Index(names))
end

function matchquality(src,mat,weights)
    #expensive
    all(src .== mat) && return 1.0
    cscore = 0.0
    #expensive to enumerate
    for (i,word) in enumerate(mat)
        word in src && (cscore += 1.0*weights[i])
    end
    cscore = cscore/length(src)
    return cscore
end

end # module