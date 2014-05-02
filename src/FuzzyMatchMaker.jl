module FuzzyMatchMaker

export buildcatalog, fuzzymatch

using DataFrames
using ArrayViews
using Distance
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
    source::Dict{ASCIIString,Set{ASCIIString}}
    Catalog() = new(Dict{ASCIIString,Set{ASCIIString}}(),Dict{ASCIIString,Set{ASCIIString}}())
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
        catalog.source[srcids[i]] = Set{ASCIIString}()
        for j = 1:scols
            f = get(repl,src[i,j],src[i,j])
            if !(f in stops)
                catalog.index[f] = push!(get(catalog.index,f,Set{ASCIIString}()),srcids[i])
                push!(catalog.source[srcids[i]],f)
            else
                push!(catalog.source[srcids[i]],"")
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
            mat[i,j] = uppercase(mat[i,j])
            word = get(repl,mat[i,j],mat[i,j])
            if !(word in stops)
                #expensive
                union!(potentials,get(catalog.index,word,Set{ASCIIString}()))
            end
        end
        indices = Array(ASCIIString,length(potentials))
        scores = zeros(length(potentials))
        mview = view(mat,i,1:mcols)
        matjoin = join(mview)
        for (ind,potmat) in enumerate(potentials)
            score = matchquality(catalog.source[potmat],mview,matjoin,weights)
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

function matchquality(src,mat,matjoin,weights)
    cscore = 0.0
    len = length(src)
    for i = 1:len
        mat[i] in src && (cscore += 1.0*weights[i])
    end
    cscore = cscore/len
    #leven = levenshtein(join(src),matjoin)/length(matjoin)
    #return max(cscore,leven)
    return cscore
end

function levenshtein{T<:String}(s1::T,s2::T;deletion_cost=1,substitution_cost=1,insertion_cost=1)
    s1len = length(s1)
    s2len = length(s2)
    if s1len == 0 
        return s2len
    elseif s2len == 0
        return s1len
    elseif s1len > s2len
        s1,s2 = s2,s1
        s1len,s2len = s2len,s1len
    end
    prev = [1:s1len+1]
    curr = [zeros(Int,s1len+1)]
    for (i2, c2) in enumerate(s2)
        curr[1] = (i2-1)
        for (i1, c1) in enumerate(s1)
            if c1 == c2
                curr[i1+1] = prev[i1]
            else
                curr[i1+1] = min(prev[i1]+substitution_cost,
                                 prev[i1+1]+deletion_cost,
                                 curr[i1]+insertion_cost)
            end
        end
        copy!(prev,curr)
    end
    return prev[end]
end

end # module