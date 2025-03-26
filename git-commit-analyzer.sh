#!/bin/bash

# =====================================================================
# Git Commit Time Analyzer
# =====================================================================
#
# このスクリプトはGitリポジトリ内の特定ユーザーのコミット時間帯を分析・可視化します
# 平日/休日別の作業パターンやピーク時間を特定することができます
#
# 作者: nakamuratetsuo
# ライセンス: MIT
# リポジトリ: https://github.com/nakamuratetsuo/git-commit-analyzer
#
# =====================================================================

# 文字コードを明示的にUTF-8に設定
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 使用方法を表示
usage() {
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  $0 [オプション]"
    echo -e ""
    echo -e "${YELLOW}オプション:${NC}"
    echo -e "  -e, --email EMAIL      コミット者のメールアドレス"
    echo -e "  -a, --author AUTHOR    コミット者の名前（完全一致）"
    echo -e "  -r, --repo PATH        Gitリポジトリのパス（デフォルト: カレントディレクトリ）"
    echo -e "  -d, --days DAYS        過去何日分を分析するか（デフォルト: 365）"
    echo -e "  -l, --list-authors     リポジトリ内のコミット者一覧を表示"
    echo -e "  -h, --help             このヘルプを表示"
    echo -e ""
    echo -e "${YELLOW}例:${NC}"
    echo -e "  $0 --email developer@example.com"
    echo -e "  $0 --author \"John Doe\" --days 30"
    echo -e "  $0 --email developer@example.com --repo /path/to/project"
    echo -e "  $0 --list-authors --repo /path/to/project"
    exit 1
}

# コミット者一覧を表示
list_authors() {
    local repo_path="$1"

    # リポジトリの存在確認
    if [ ! -d "$repo_path/.git" ]; then
        echo -e "${RED}エラー: '$repo_path' は有効なGitリポジトリではありません${NC}"
        exit 1
    fi

    # リポジトリパスを安全に表示（絶対パスの場合はチルダ表記に変換）
    local display_path="$repo_path"
    if [[ "$repo_path" == /* ]]; then
        # 絶対パスの場合
        if [[ "$repo_path" == "$HOME"* ]]; then
            # ホームディレクトリ内の場合はチルダに置換
            display_path="~${repo_path#$HOME}"
        else
            # ホームディレクトリ外の絶対パスの場合は最後のディレクトリ名のみ表示
            display_path=".../${repo_path##*/}"
        fi
    fi

    echo -e "${BLUE}============================================================${NC}"
    echo -e "${YELLOW}      リポジトリ内のコミット者一覧       ${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}リポジトリ: ${NC}${display_path}"
    echo ""

    echo -e "${YELLOW}[コミット者名とメールアドレス]${NC}"
    cd "$repo_path" && git log --format='%an <%ae>' | sort | uniq

    echo ""
    echo -e "${YELLOW}[コミット数の多い順（上位10名）]${NC}"
    cd "$repo_path" && git shortlog -sn --no-merges | head -10

    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${YELLOW}注: コミット者名を使用する場合は、上記の名前を ${GREEN}--author${NC} オプションに${RED}完全一致${NC}で指定してください。${NC}"
    echo -e "${YELLOW}    (例: ${GREEN}--author \"John Doe\"${NC})${NC}"
    echo -e "${YELLOW}注: 名前が完全一致してもコミットが見つからない場合は、メールアドレスも指定してみてください。${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

# デフォルト値
REPO_PATH="."
DAYS=365
AUTHOR=""
EMAIL=""
LIST_AUTHORS=false

# 引数のパース
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -a|--author)
            AUTHOR="$2"
            shift 2
            ;;
        -r|--repo)
            REPO_PATH="$2"
            shift 2
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -l|--list-authors)
            LIST_AUTHORS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}エラー: 不明なオプション '$1'${NC}"
            usage
            ;;
    esac
done

# コミット者一覧を表示する場合
if [ "$LIST_AUTHORS" = true ]; then
    list_authors "$REPO_PATH"
    exit 0
fi

# 必要な引数の確認
if [[ -z "$AUTHOR" && -z "$EMAIL" ]]; then
    echo -e "${RED}エラー: コミット者のメールアドレス(-e)またはコミット者の名前(-a)が必要です${NC}"
    echo -e "${YELLOW}ヒント: リポジトリ内のコミット者一覧を確認するには ${GREEN}--list-authors${NC} オプションを使用してください${NC}"
    usage
fi

# Gitリポジトリのチェック
if [ ! -d "$REPO_PATH/.git" ]; then
    echo -e "${RED}エラー: '$REPO_PATH' は有効なGitリポジトリではありません${NC}"
    exit 1
fi

# ヘッダーの表示
print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${YELLOW}      Gitコミット時間の可視化       ${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""

    if [ ! -z "$AUTHOR" ]; then
        echo -e "${CYAN}コミット者: ${NC}${GREEN}$AUTHOR${NC}（完全一致）"
    fi

    if [ ! -z "$EMAIL" ]; then
        echo -e "${CYAN}メールアドレス: ${NC}${GREEN}$EMAIL${NC}"
    fi

    # 最初のコミットの情報を取得
    local git_author_param=""
    if [ ! -z "$AUTHOR" ]; then
        # 最初のコミット取得でも同じ検索パターンを使用
        git_author_param="$AUTHOR"
        local first_commit=$(cd "$REPO_PATH" && git log --author="$git_author_param" --perl-regexp --author="\\b${git_author_param}\\b" --reverse --format="%H %ai" | head -1)
    else
        git_author_param="${EMAIL}"
        local first_commit=$(cd "$REPO_PATH" && git log --author="${git_author_param}" --reverse --format="%H %ai" | head -1)
    fi

    if [ ! -z "$first_commit" ]; then
        local commit_hash=$(echo $first_commit | cut -d' ' -f1)
        local commit_date=$(echo $first_commit | cut -d' ' -f2)
        echo -e "${CYAN}最初のコミット: ${NC}${GREEN}${commit_hash:0:12}${NC} (${commit_date})"
    fi

    # リポジトリパスを安全に表示（絶対パスの場合はチルダ表記に変換）
    local display_path="$REPO_PATH"
    if [[ "$REPO_PATH" == /* ]]; then
        # 絶対パスの場合
        if [[ "$REPO_PATH" == "$HOME"* ]]; then
            # ホームディレクトリ内の場合はチルダに置換
            display_path="~${REPO_PATH#$HOME}"
        else
            # ホームディレクトリ外の絶対パスの場合は最後のディレクトリ名のみ表示
            display_path=".../${REPO_PATH##*/}"
        fi
    fi

    echo -e "${CYAN}リポジトリ: ${NC}${display_path}"
    echo -e "${CYAN}分析期間: ${NC}過去 ${DAYS} 日間"
    echo ""
}

# コミット時間と曜日を取得
get_commit_times_and_days() {
    local cmd_times="cd \"$REPO_PATH\" && git log --format='%ad' --date=format-local:'%H %u'"

    if [ ! -z "$AUTHOR" ]; then
        # 著者名の完全一致を実現するために正しいパターンを使用
        # ^ と $ はgitの --author フラグと一緒に使うと機能しないので別の方法を使う
        cmd_times="$cmd_times --author=\"$AUTHOR\" --perl-regexp --author='\\b${AUTHOR}\\b'"
    fi

    if [ ! -z "$EMAIL" ]; then
        cmd_times="$cmd_times --author=\"$EMAIL\""
    fi

    cmd_times="$cmd_times --since=\"$DAYS days ago\""

    eval "$cmd_times"
}

# コミット分析と表示
analyze_commits() {
    # コミット時間と曜日のデータを取得
    local commit_data=$(get_commit_times_and_days)

    # 平日（1-5）と休日（6-7）の時間帯別コミット数を集計
    declare -a weekday_counts
    declare -a weekend_counts
    for i in {0..23}; do
        weekday_counts[$i]=0
        weekend_counts[$i]=0
    done

    local total_weekday=0
    local total_weekend=0

    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        local hour=$(echo $line | cut -d' ' -f1)
        local day=$(echo $line | cut -d' ' -f2)

        # 数値として確実に処理するため、10進数として明示的に扱う
        hour=$((10#$hour))
        day=$((10#$day))

        # 0-23の範囲内であることを確認
        if [ $hour -ge 0 ] && [ $hour -le 23 ]; then
            if [ $day -ge 1 ] && [ $day -le 5 ]; then
                # 平日
                ((weekday_counts[$hour]++))
                ((total_weekday++))
            else
                # 休日
                ((weekend_counts[$hour]++))
                ((total_weekend++))
            fi
        fi
    done <<< "$commit_data"

    # 総コミット数
    local total_commits=$((total_weekday + total_weekend))

    if [ $total_commits -eq 0 ]; then
        echo -e "${RED}コミットが見つかりませんでした${NC}"
        exit 1
    fi

    # 平日と休日の割合
    local weekday_percent=0
    local weekend_percent=0

    if [ $total_commits -gt 0 ]; then
        weekday_percent=$(echo "scale=1; $total_weekday * 100 / $total_commits" | bc)
        weekend_percent=$(echo "scale=1; $total_weekend * 100 / $total_commits" | bc)
    fi

    # 全体の最大値を取得（平日と休日を含む）
    local max_count=0
    for h in {0..23}; do
        if [ ${weekday_counts[$h]} -gt $max_count ]; then
            max_count=${weekday_counts[$h]}
        fi
        if [ ${weekend_counts[$h]} -gt $max_count ]; then
            max_count=${weekend_counts[$h]}
        fi
    done

    # アスタリスクを生成する関数（共通スケール版）
    generate_stars() {
        local count=$1
        local max_value=$2
        local max_stars=40

        # コミット数が0の場合は空文字列を返す
        if [ $count -eq 0 ]; then
            echo ""
            return
        fi

        # 対数スケーリングを使用して星の数を決定
        # 単純比例よりも差が見やすくなる
        local ratio=$(echo "l($count + 1) / l($max_value + 1)" | bc -l 2>/dev/null)
        if [ -z "$ratio" ] || [ $(echo "$ratio < 0" | bc) -eq 1 ]; then
            ratio=0.1  # エラーまたは負の値の場合、最小値を設定
        fi

        local stars_count=$(echo "$ratio * $max_stars" | bc)
        stars_count=${stars_count%.*}  # 小数点以下を切り捨て

        # 最低1つのアスタリスクを確保
        if [ $count -gt 0 ] && [ $stars_count -lt 1 ]; then
            stars_count=1
        fi

        # アスタリスクを生成
        local result=""
        for ((i=0; i<$stars_count; i++)); do
            result+="*"
        done

        echo "$result"
    }

    # 結果を表示
    echo ""
    echo "           Monday to Friday                   Saturday and Sunday"
    echo -e "${YELLOW}hour${NC}"

    for h in {0..23}; do
        local weekday_count=${weekday_counts[$h]}
        local weekend_count=${weekend_counts[$h]}

        # 共通の最大値を使用してスケーリング
        local weekday_stars=$(generate_stars $weekday_count $max_count)
        local weekend_stars=$(generate_stars $weekend_count $max_count)

        # 出力処理を純粋なecho方式に変更
        echo -e "${PURPLE}$(printf "%02d" $h)${NC}    ${GREEN}$(printf "%-3d" $weekday_count)${NC}${weekday_stars}$(printf "%$((40-${#weekday_stars}))s" "")    ${GREEN}$(printf "%-3d" $weekend_count)${NC}${weekend_stars}"
    done

    echo ""
    echo -e "${YELLOW}Total:${NC}  ${GREEN}$total_weekday (${weekday_percent}%)${NC}$(printf "%40s" "")${GREEN}$total_weekend (${weekend_percent}%)${NC}"

    # 作業パターンを分析（引数を展開せず直接渡す）
    analyze_work_pattern "${weekday_percent}" "${weekend_percent}" "${total_commits}"
}

# 作業パターンの分析
analyze_work_pattern() {
    local weekday_percent="$1"
    local weekend_percent="$2"
    local total_commits="$3"

    echo ""
    echo -e "${CYAN}作業パターンの分析:${NC}"

    # 平日と休日の比率から
    if (( $(echo "$weekday_percent > 80" | bc -l) )); then
        echo -e "- 平日に集中して作業し、休日はほとんど作業しない傾向があります。"
    elif (( $(echo "$weekday_percent < 60" | bc -l) )); then
        echo -e "- 平日と休日の区別なく作業する傾向があります。"
    else
        echo -e "- 平日が中心ですが、休日も一定量の作業をしています。"
    fi

    # ピーク時間を特定
    local max_hour=0
    local max_count=0
    for h in {0..23}; do
        local total_count=$((weekday_counts[$h] + weekend_counts[$h]))
        if [ $total_count -gt $max_count ]; then
            max_count=$total_count
            max_hour=$h
        fi
    done

    # 作業時間帯の特定
    local active_hours=""
    for h in {0..23}; do
        local total_count=$((weekday_counts[$h] + weekend_counts[$h]))
        # 最大値の25%以上のコミットがある時間を「活発」と定義
        if [ $total_count -gt $(($max_count / 4)) ]; then
            if [ -z "$active_hours" ]; then
                active_hours="$h"
            else
                active_hours="$active_hours, $h"
            fi
        fi
    done

    # 日本語文字を含む文字列を直接出力（printf処理を避ける）
    echo -e "- 最も活発な時間帯は ${YELLOW}${max_hour}時${NC} で、${YELLOW}${max_count}件${NC} のコミットがあります。"

    if [ -n "$active_hours" ]; then
        echo -e "- 活発に作業している時間帯: ${YELLOW}${active_hours}時${NC}"
    fi

    # 作業スタイルの分析
    if [ $max_hour -ge 9 ] && [ $max_hour -le 17 ]; then
        echo -e "- 一般的な業務時間内に最も活発に作業する傾向があります。"
    elif [ $max_hour -ge 22 ] || [ $max_hour -le 5 ]; then
        echo -e "- 夜間から深夜にかけて活発に活動する夜型の傾向があります。"
    elif [ $max_hour -ge 5 ] && [ $max_hour -le 8 ]; then
        echo -e "- 早朝から活動を始める朝型の傾向があります。"
    fi

    echo -e "- 分析期間中の総コミット数: ${GREEN}${total_commits}${NC}"
}

# メイン処理
clear
print_header
analyze_commits

echo -e "\n${BLUE}============================================================${NC}"
echo -e "${YELLOW}注: この分析はGitコミット時間に基づいており、実際の作業時間とは異なる場合があります。${NC}"
echo -e "${BLUE}============================================================${NC}"

# スクリプト終了前に入力待ち
echo -e "\n${GREEN}Enterキーを押すと終了します...${NC}"
read
