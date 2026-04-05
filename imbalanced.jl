using StatsBase, HTTP, JSON, Printf, CSV, DataFrames
function imbalance(solves::Vector)
    ratios = @. log1p(solves[2:end]) - log1p(solves[1:end-1])
    return std(ratios; corrected=false)
end
const jar = HTTP.Cookies.CookieJar()
function standings(x)
    fetched = HTTP.get("https://codeforces.com/api/contest.standings?contestId=$x&participantTypes=CONTESTANT"; cookiejar=jar)
    JSON.parse(String(fetched.body))["result"]["rows"], fetched.status
end
function solves(id)
    X, fstat = standings(id)
    scnt = fill(0, length(X[1]["problemResults"]))
    for i ∈ X, (k, j) ∈ enumerate(i["problemResults"])
        if j["points"] > 0.0; scnt[k] += 1; end
    end
    scnt, fstat
end
eta(s) = @sprintf("%02d:%02d:%06.3f", Int(s÷3600), Int(s÷60)%60, s%60)
println(stderr, "fetching contest list")
cl = JSON.parse(String(HTTP.get("https://codeforces.com/api/contest.list?gym=false"; cookiejar=jar).body))["result"]
println(stderr, "going thru contests")
i0 = 1
k = ndigits(length(cl))
ttt = 0
pvdata = Dict([x[1] => collect(x) for x ∈ eachrow(CSV.read(ARGS[1], DataFrame))])
open(ARGS[2], "w") do fobj
    println(fobj, "ID|Starting time|Contest title|Contest imbalance")
    fstat = 0
    while i0 <= length(cl)
        t1 = time()
        info = cl[i0]
        i = info["id"]
        if i ∈ keys(pvdata)
            println(fobj, join(pvdata[i], '|'))
        else
            if info["phase"] != "FINISHED"; global i0 += 1; println(stderr, "skipped $i"); continue; end
            try
                solvecounts, fstat = solves(i)
                println(fobj, "$i|$(info["startTimeSeconds"])|$(info["name"])|$(imbalance(solvecounts))")
            catch e
                if e isa HTTP.Exceptions.StatusError
                    println(stderr, "\nfailed fetch for $i: $e")
                    if fstat == 403; sleep(30 + 30rand()); end
                elseif e isa InterruptException
                    throw(e)
                else
                    println(stderr, "\nfailed at $i: $e")
                end
            end
            t2 = time()
            x = 3+1.6rand()
            if t2-t1 < x; sleep(x-t2+t1); end
        end
        global i0 += 1
        t3 = time()
        global ttt += t3-t1
        println(stderr, @sprintf("contest %d: %*d/%d, %6.2f%%, eta %s", i, k, i0-1, length(cl), 100*(i0-1)/length(cl), eta((length(cl)-i0+1)*ttt/(i0-1))))
    end
end

