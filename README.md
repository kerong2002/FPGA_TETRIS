# FPGA_TETRIS
FPGA_TETRIS
### 樣式圖
<img src="https://github.com/kerong2002/FPGA_TETRIS/blob/main/tetris%E6%A8%A3%E5%BC%8F%E5%9C%96.jpg" alt="krameri120's TETRIS" width="46%" />

### 方塊圖
<img src="https://github.com/kerong2002/FPGA_TETRIS/blob/main/tetris_shape_cut.PNG" alt="krameri120's TETRIS" width="46%" />

## 操作說明

|KEY_BOARD|操作|KEY_BOARD|操作|
|:-:|:-:|:-:|:-:|
|left|向左移動|right|向右移動|
|down|快速降落|space|直接降落|
|z|左旋轉|x|右旋轉|
|up|左旋轉|ENTER|開始遊戲|
|shift|hold|c|hold| 


1. IR -> 速度調整
2. VGA -> 顯示畫面
3. LCD -> 顯示時間和分數
4. PS2 -> 操作

## 2022/12/23
- 1 PS2 設定
- 2 PS2 雙鍵問題解決
- 3 設定PS2 掃描第二個按鍵

## 2022/12/24
- 1 PS2 shift設定key1 和 key2 都會觸發
- 2 TETRIS 圖形設定
- 3 TETRIS 選轉圖形定義
- 4 TETRIS 位置設定
- 5 連接VGA螢幕測試
- 6 寬度高度調整
- 7 圖形顯示比例調整
- 8 邊界設定

## 2022/12/25
- 1 方塊掉落調整
- 2 方塊資料問題
- 3 鍵盤移動
- 4 移動跟下降分頻
- 5 放置方塊後更新board
- 6 下方邊界判定
- 7 邊界方塊放置

## 2022/12/26
- 1 IR 控制方塊降落速度
- 2 四種遊戲速度控制
- 3 調整除頻比例
- 4 方塊顏色調整
- 5 T圖形資料更改
- 6 左右keyboard選轉更新
- 7 enter 觸發開始
- 8 方塊疊加
- 9 方塊放置判定
- 10 下一個方塊顯示
- 11 方塊消除
- 12 方塊初始位置調整
- 13 計時器設定

## 2022/12/27
- 1 overflow 方格轉型T
- 2 右邊界設定
- 3 下一個方塊顯示
- 4 LFSR不夠亂
- 5 更新LFSR數值
- 6 畫面調整

## 2022/12/28
- 1 左右移動判定
- 2 選轉判定
- 3 邊緣選轉判定
- 4 加入顏色
- 5 (問題:hold)
- 6 (問題:下降)
- 7 快速下降功能
- 8 按鍵調整
- 9 PS2更新寫法

## 2022/12/29
- 1 時間bug修復
- 2 hold 方塊
## 2022/12/30
- 1 加入聲音
