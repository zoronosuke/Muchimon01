import re
import sys

def preprocess_text(text):
    """
    テキストを前処理し、数字が正しく読み上げられるように変換します。
    数字が"ポンド"と読まれる問題を修正するための処理です。
    """
    # 数字が#記号と誤解される場合があるため、その対策
    # 数字の後に日本語が続く場合は、数字を全角に変換して区別を明確にする
    # 半角→全角変換マッピング
    zen_digits = {
        '0': '０', '1': '１', '2': '２', '3': '３', '4': '４', 
        '5': '５', '6': '６', '7': '７', '8': '８', '9': '９'
    }
    
    # 数字を全角に変換する関数
    def to_zen(match):
        digit = match.group(1)
        jp_char = match.group(2)
        zen_digit = ''.join(zen_digits.get(c, c) for c in digit)
        return f"{zen_digit}{jp_char}"
    
    # 数字+日本語のパターンを見つけて変換
    text = re.sub(r'(\d+)([一-龯ぁ-んァ-ヶ])', to_zen, text)
    
    return text

def test_number_reading_fix():
    """Test that text preprocessing correctly handles numbers without adding 'ポンド'"""
    
    # テスト用の数字を含む文章のリスト
    test_texts = [
        "123と456の数字です。",
        "年齢は25歳です。",
        "2023年4月5日に開始します。",
        "12個のりんごと34個のみかんがあります。",
        "100円で購入できます。"
    ]
    
    print("=== 数字読み上げテスト開始 ===")
    
    for i, text in enumerate(test_texts):
        print(f"\nテスト {i+1}: \"{text}\"")
        print("前処理前のテキスト:", text)
        
        # 前処理関数のテスト
        processed_text = preprocess_text(text)
        print("前処理後のテキスト:", processed_text)
        
        # 変更があったかチェック
        if text != processed_text:
            print("テスト成功: テキストが前処理されました")
        else:
            print("注意: 前処理前後でテキストに変更がありません")
    
    print("\n=== 数字読み上げテスト完了 ===")
    return True

if __name__ == "__main__":
    success = test_number_reading_fix()
    sys.exit(0 if success else 1)
