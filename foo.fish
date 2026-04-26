#!/usr/bin/env fish
set contents (cat ./commits)
echo OUTPUT > output
set first a82ccc39b39b621151d6732718e3e250109076fa
set last dd9b079222d43e1943b6ebd802f04fd959dc8e61
set inc 100
set contents (git rev-list $first..$last | tac)
set size (echo $contents | string split " " |  wc -l)
echo "Size of $size"
for i in (seq $size)
    if test (math "$i % $inc") = 0
        echo "passed with i=$i"
        set commit $contents[$i]
        echo "commit $commit"
        git checkout -q -f $commit
        set json (NIX_SHOW_STATS=1 nix eval -f ./default.nix git 2>&1 | tail -n +2)
        echo $json
        set time (echo $json | jq -r '.envs.bytes')
        echo "iteration $i | commit $commit | time $time" >> output
    end
end
