//+------------------------------------------------------------------+
//|                                                AutoLineTrade.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
#include <stdlib.mqh>

input bool Demo = true;

input int MAGIC = 0;
input int Slippage=3;

enum MODE_account {デモ検証=0,リアル口座　=1};
input MODE_account isDemo =0;//稼働チェック

input int order_trial_num = 5;

//取引ロット関連
input int MaxPosition=1;
input double Lots=0.01;
input int takeprofit=7;//TS発動pips
input int stoploss=5;
input int exitTypePer=1;//TS発動時の最小TP

input bool line_notify = false;//ラインに通知をするか
input string line_token = "<token>";//LINEのアクセストークン
input string Send_Massage ="<message>";//LINEに送りたいメッセージ

input bool discord_notify = false;//Discordに通知をするか
input string bot_name = "投資通知ちゃま";
input string discord_webhook = "<webhook>";//Discordのwebhook


#include <CustomObjects.mqh>


//通貨のpipsを取得するよ。最小point が
//0.001, 0.01 (USD/JPY, EUR/JPY) etc は pips 0.01
double pips = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   pips = AdjustPoint();
   if (pips == 0){
      MessageBox("マーケット情報が取得できませんでした。","エラー",MB_ICONINFORMATION);
      return(INIT_FAILED);
   }
   
   
   
   //LineNotify(Line_token,Send_Massage);//LineNotifyを呼び出し
   //DiscordNotify(bot_name,discord_webhook,Send_Massage);//LineNotifyを呼び出し
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

   if(Bars<0)return ;
   Comment("最大バー数:",Bars);
   
   static bool initialized = false;//最初の一回関数制限
   //最初一回の関数
   if(!initialized){
      Print("first init");
      initialized = true;
   }
   
   
   
   static datetime tmp_time = Time[0];
   static double pre_close=Close[0];
   
   int u = PositionCount();
   //Comment("現在のポジション数:",u);
   Comment("現在のスプレッド:",MarketInfo(Symbol(),MODE_SPREAD));
   //Comment("Hello",MarketInfo(Symbol(),MODE_TICKSIZE));
   if(u==0){
      for(int i=ObjectsTotal()-1;i>=0;i--){
         if(ObjectGetInteger(NULL,ObjectName(i),OBJPROP_TYPE)==OBJ_HLINE){
            double price = ObjectGetDouble(NULL,ObjectName(i),OBJPROP_PRICE);
            //上から下にクロス　または　下から上にクロス
            if( ( pre_close<price && price<=Close[0] ) || ( pre_close>price && price>=Close[0] )){
               if(ObjectGet(ObjectName(i),OBJPROP_COLOR) == clrYellow){
                  order(OP_BUY);
               
               } else if(ObjectGet(ObjectName(i),OBJPROP_COLOR) == clrPink){
                  order(OP_SELL);
               }
               //OrderSend(Symbol(),OP_SELL,Lots ,Bid,Slippage,Bid-25*pips,Bid+25*pips,"AutoLineEntry",MAGIC,0,clrBlue); 
            }
            //if(line_notify)LineNotify(line_token,message);
            //if(discord_notify)DiscordNotify(bot_name,discord_webhook,message)
         }
      }
   }
   
   pre_close=Close[0];
   
   //新しいろうそく足関数
   if(tmp_time!=Time[0]){
      Print("new candle");
      tmp_time=Time[0];
   } 
}
//+------------------------------------------------------------------+

void order(ENUM_ORDER_TYPE type){

   int result = 0;//OrderSend result 
   double spread = MarketInfo(Symbol(),MODE_SPREAD);
   for(int count = 0; count < order_trial_num ; count ++ ) {
      // スリップ上限(int)[分解能 0.1pips]   ( symbol / type / Lots / price / slip / sl / tp / comment / expiration / color );
      if(type == OP_BUY){
         result = OrderSend(Symbol(),OP_BUY,Lots ,Ask,Slippage,Ask-3*pips,Ask+3*pips,"AutoLineEntry",MAGIC,0,clrRed);
      } else if(type == OP_SELL){
         result = OrderSend(Symbol(),OP_SELL,Lots ,Bid,Slippage,Bid+3*pips,Bid-3*pips,"AutoLineEntry",MAGIC,0,clrBlue);
      }
      if ( result == -1 ){
         int errorcode = GetLastError();      // エラーコード取得
         if( errorcode != ERR_NO_ERROR ) { // エラー発生
             printf("エラーコード:%d , 詳細:%s ", errorcode , ErrorDescription(errorcode));
         }
         Sleep(1000);                                           // 1000msec待ち
         RefreshRates();                                        // レート更新
         //printf("再エントリー要求回数:%d, 更新エントリーレート:%g", count+1 , ea_order_entry_price );
         
      } else {    // 注文約定
         Print("新規注文約定。 チケットNo=",result);
         break;
      }
   }
}



//ポジションクローズ関数
void CloseOrder(int ClosePosition){
	for(int i=OrdersTotal()-1;i>=0;i--){
		int res;
		if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true){
			if(OrderMagicNumber()==MAGIC && OrderSymbol()==Symbol()){

				if(OrderType()==OP_SELL && (ClosePosition==-1 || ClosePosition==0 )){
					res=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,clrGreen);
				}
				else if(OrderType()==OP_BUY && (ClosePosition==1 || ClosePosition==0 )){
					res=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,clrGreen);
				}
			}
		}
	}
}

//ポジションカウント関数
int PositionCount(){
   int count =0;
   string mes = "";
	for(int i=OrdersTotal()-1;i>=0;i--){
		if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
			if(OrderMagicNumber()==MAGIC && OrderSymbol()==Symbol()){
			   count++;
			}
		}
	}
	return count;
}

double AdjustPoint(){
	int digits=(int)MarketInfo(Symbol(),MODE_DIGITS);
	
	if ( digits==2 || digits==3 )    return 0.01;
	else if (digits==4 || digits==5) return 0.0001;
	else if (digits==1)              return 0.1;
	else if (digits==0)              return 1;
	else                             return 0;
}


void LineNotify(string token,string message){
   char data[], result[];//データ、結果
   
   // ヘッダー部分の作成
   string headers="Authorization: Bearer "+token+"\r\n	application/x-www-form-urlencoded\r\n";
   //　メッセージ配列の作成
   ArrayResize(data,StringToCharArray("message="+message,data,0,WHOLE_ARRAY,CP_UTF8)-1);
   
   int res = WebRequest("POST", "https://notify-api.line.me/api/notify", headers, 0, data, result, headers);
   if(res==-1){ 
      Print("Error in WebRequest. Error code  =",GetLastError()); 
      //MessageBox("","Error",MB_ICONINFORMATION); 
   } 
}

void DiscordNotify(string bot, string webhook,string message){
   char data[], result[];//データ、結果
   
   // ヘッダー部分の作成
   string headers = "Content-Type: application/json\r\n";
   //　メッセージ配列の作成
   string mes = "{\"username\":\""+bot+"\",\"content\":\""+message+"\"}"; 
   ArrayResize(data,StringToCharArray(mes,data,0,WHOLE_ARRAY,CP_UTF8)-1);
   
   int res = WebRequest("POST", webhook, headers, 0, data, result, headers);
   if(res==-1){ 
      Print("Error in WebRequest. Error code  =",GetLastError());
   } 
}