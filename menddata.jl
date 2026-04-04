using CSV, DataFrames, HTTP, JSON
df = CSV.read(ARGS[1], DataFrame)
asjson(url) = JSON.parse(String(HTTP.get(url).body))
data = asjson("https://codeforces.com/api/contest.list?gym=false")["result"]
ctsts = Dict()
for i ∈ data
    ctsts[i["id"]] = i
end
open(ARGS[2], "w") do fobj
    println(fobj, "ID|Starting time|Contest title|Contest imbalance")
    for (id, imb) ∈ eachrow(df)
        println(stderr, id)
        t1 = time()
        println(fobj, "$id|$(ctsts[id]["startTimeSeconds"])|$(ctsts[id]["name"])|$imb")
        t2 = time()
        # if t2-t1 <= 0.3; sleep(0.3-t2+t1); end
    end
end
