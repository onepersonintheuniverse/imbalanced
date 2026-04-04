using StatsBase, HTTP, JSON, Printf
function imbalance(solves::Vector)
    ratios = @. log1p(solves[2:end]) - log1p(solves[1:end-1])
    return std(ratios; corrected=false)
end
const jar = HTTP.Cookies.CookieJar()
standings(x) = JSON.parse(String(HTTP.get("https://codeforces.com/api/contest.standings?contestId=$x&participantTypes=CONTESTANT"; cookiejar=jar).body))["result"]["rows"]
function solves(id)
    X = standings(id)
    scnt = fill(0, length(X[1]["problemResults"]))
    for i ∈ X, (k, j) ∈ enumerate(i["problemResults"])
        if j["points"] > 0.0; scnt[k] += 1; end
    end
    scnt
end
eta(s) = @sprintf("%02d:%02d:%06.3f", Int(s÷3600), Int(s÷60)%60, s%60)
println(stderr, "fetching contest list")
cl = JSON.parse(String(HTTP.get("https://codeforces.com/api/contest.list?gym=false"; cookiejar=jar).body))["result"]
println(stderr, "going thru contests")
i0 = 1
k = ndigits(length(cl))
ttt = 0
while i0 <= length(cl)
    t1 = time()
    info = cl[i0]
    i = info["id"]
    if info["phase"] != "FINISHED"; global i0 += 1; println(stderr, "skipped $i"); continue; end
    try
        println("$i,$(imbalance(solves(i)))")
    catch e
        if e isa HTTP.Exceptions.StatusError
            println(stderr, "\nfailed fetch for $i: $e")
            sleep(30 + 30rand())
        elseif e isa InterruptException
            throw(e)
        else
            println(stderr, "\nfailed at $i: $e")
        end
    end
    global i0 += 1
    t2 = time()
    x = 3+1.6rand()
    if t2-t1 < x; sleep(x-t2+t1); end
    t3 = time()
    global ttt += t3-t1
    println(stderr, @sprintf("contest %d: %*d/%d, %6.2f%%, eta %s", i, k, i0, length(cl), 100*i0/length(cl), eta((length(cl)-i0+1)*ttt/(i0-1))))
end

