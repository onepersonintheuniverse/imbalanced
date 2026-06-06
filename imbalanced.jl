using StatsBase, HTTP, JSON, Printf, CSV, DataFrames, Dates
function imbalance(solves::Vector)
    ratios = @. log1p(solves[2:end]) - log1p(solves[1:end-1])
    return std(ratios; corrected=false)
end
const jar = HTTP.Cookies.CookieJar()
function standings(x)
    fetched = HTTP.get("https://codeforces.com/api/contest.standings?contestId=$x"; cookiejar=jar)
    filter(x -> x["party"]["participantType"] == "CONTESTANT", JSON.parse(String(fetched.body))["result"]["rows"]), fetched.status
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
global skiplist = Set()
try
    global skiplist = Set(tryparse.(Int, readlines("status400.txt")))
catch e
    println("couldn't parse status400 file: $e")
end
vals = []
open(ARGS[2], "w") do fobj
    open("status400.txt", "w") do skipf
        println(fobj, "ID,Starting time (UTC),Contest title,Contest imbalance")
        fstat = 0
        while i0 <= length(cl)
            t1 = time()
            info = cl[i0]
            i = info["id"]
            if i ∈ keys(pvdata)
                u = pvdata[i][2] isa DateTime ? pvdata[i][2] : unix2datetime(pvdata[i][2]);
                println(fobj, "$(pvdata[i][1]),$u,\"$(pvdata[i][3])\",$(pvdata[i][4])")
                v = pvdata[i][4]
                if !isnan(v) && !isinf(v); push!(vals, v); end
            elseif i ∈ skiplist; global i0 += 1; println(stderr, "skipped $i"); println(skipf, i)
            elseif info["phase"] != "FINISHED"; global i0 += 1; println(stderr, "skipped $i")
            else
                try
                    solvecounts, fstat = solves(i)
                    println(fobj, "$i,$(unix2datetime(info["startTimeSeconds"])),\"$(info["name"])\",$(imbalance(solvecounts))")
                    println(pilf, imbalance(solvecounts))
                catch e
                    if e isa HTTP.Exceptions.StatusError
                        global fstat = e.status
                        println(stderr, "failed fetch for $i: status $fstat")
                        if fstat == 400; println(skipf, i); end
                        if fstat == 403; sleep(30 + 30rand()); end
                    elseif e isa InterruptException
                        throw(e)
                    elseif e isa BoundsError
                        println(stderr, "malformed standings for $i")
                        println(skipf, i)
                    else
                        println(stderr, "failed at $i: $e")
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
end

mx = maximum(vals)
nbins = 1+trunc(Int, mx/0.1)
counts = fill(0, nbins)

open(ARGS[3], "w") do pilf
    for i ∈ vals
        counts[1+trunc(Int, i/0.1)] += 1
    end
    for i ∈ 1:nbins
        println(pilf, "$((i-1)*0.1) $(counts[i])")
    end
end
