count=$(cat modified_files.txt | wc -l)

if [ "$count" -eq 1 ]; then
result=$(cat modified_files.txt | awk -F '/' '{print $1"/"$2}')
echo $result
else

cat modified_files.txt | awk '

BEGIN { FS="/" }
{
    prefix = $1 "/" $2
    if (NR ==1) {
        common = prefix
    } else if (common != prefix) {
        common = ""
    }
}
END {
    if (common != "") {
        print common
    }
}'
fi