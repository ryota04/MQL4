//+------------------------------------------------------------------+
//|                                                       ZigZag.mq4 |
//|                   Copyright 2006-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+


        /////////////////////////////////////////////////////////////
        /////////////////////////////////////////////////////////////
        //   通常verのv3に＋でMAフィルターを足す                  　      //
        /////////////////////////////////////////////////////////////
        /////////////////////////////////////////////////////////////



#property copyright "2006-2014, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property strict

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Red
//---- indicator parameters
input int InpDepth=4;     // Depth
input int InpDeviation=2;  // Deviation
input int InpBackstep=3;   // Backstep
//---- indicator buffers
double ExtZigzagBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];

double HighBuffer[350];
double LowBuffer[350];
int    LowIndexBuffer[100];
int    HighIndexBuffer[100];

extern int minBars = 30;
extern int minBars2 = 50;
extern int n_point = 1; // TLの支えで離れてる許容point
extern int n_point2 = 10;

extern color  Support       = DeepSkyBlue;
extern color  Resistance    = Red;

int distBars = 9; //　書く支えが最低どれだけのバー離れていないといけないか
int distBars2 = 45; //　

int bars = 400; // 今回計算するバーの最大数


int MaFilter1 = 75;
int MaFilter2 = 200;
int TimeF = 15;

//--- globals
int ExtLevel=3; // recounting's depth of extremums
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   DeleteTL();   
   if(InpBackstep>=InpDepth)
     {
      Print("Backstep cannot be greater or equal to Depth");
      return(INIT_FAILED);
     }
//--- 2 additional buffers
   IndicatorBuffers(5);
//---- drawing settings
   SetIndexStyle(0,DRAW_NONE);
//---- indicator buffers
   SetIndexBuffer(0,ExtZigzagBuffer);
   SetIndexBuffer(1,ExtHighBuffer);
   SetIndexBuffer(2,ExtLowBuffer);   
   SetIndexBuffer(3,HighBuffer);
   SetIndexBuffer(4,LowBuffer);
   SetIndexEmptyValue(0,0.0);
//---- indicator short name
   IndicatorShortName("ZigZag("+string(InpDepth)+","+string(InpDeviation)+","+string(InpBackstep)+")");
   
//---- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
  {
   int    i,limit,counterZ,whatlookfor=0;
   int    back,pos,lasthighpos=0,lastlowpos=0;
   double extremum;
   double curlow=0.0,curhigh=0.0,lasthigh=0.0,lastlow=0.0;
//--- check for history and inputs
   if(rates_total<InpDepth || InpBackstep>=InpDepth)
      return(0);
//--- first calculations
   if(isNewBar(_Symbol, 0)){ 
      if(prev_calculated==0)
         limit=InitializeAll();
      else 
        {
         //--- find first extremum in the depth ExtLevel or 100 last bars
         i=counterZ=0;
         while(counterZ<ExtLevel && i<100)
           {
            if(ExtZigzagBuffer[i]!=0.0)
               counterZ++;
            i++;
           }
         //--- no extremum found - recounting all from begin
         if(counterZ==0)         // 直近100本のバーの範囲で一つも山もしくわ谷が無い場合。
            limit=InitializeAll();
         else
           {
            //--- set start position to found extremum position
            limit=i-1;
            //--- what kind of extremum?
            if(ExtLowBuffer[i]!=0.0) 
              {
               //--- low extremum
               curlow=ExtLowBuffer[i];
               //--- will look for the next high extremum
               whatlookfor=1;
              }
            else
              {
               //--- high extremum
               curhigh=ExtHighBuffer[i];
               //--- will look for the next low extremum
               whatlookfor=-1;
              }
            //--- clear the rest data
            for(i=limit-1; i>=0; i--)  
              {
               ExtZigzagBuffer[i]=0.0;  
               ExtLowBuffer[i]=0.0;
               ExtHighBuffer[i]=0.0;
              }
           }
        }
   //--- main loop      
      for(i=limit; i>=0; i--)
        {
         //--- find lowest low in depth of bars
         extremum=low[iLowest(NULL,0,MODE_LOW,InpDepth,i)];
         //--- this lowest has been found previously
         if(extremum==lastlow)
            extremum=0.0;
         else 
           { 
            //--- new last low
            lastlow=extremum; 
            //--- discard extremum if current low is too high
            if(low[i]-extremum>InpDeviation*Point)
               extremum=0.0;
            else
              {
               //--- clear previous extremums in backstep bars
               for(back=1; back<=InpBackstep; back++)
                 {
                  pos=i+back;
                  if(ExtLowBuffer[pos]!=0 && ExtLowBuffer[pos]>extremum)
                     ExtLowBuffer[pos]=0.0; 
                 }
              }
           } 
         //--- found extremum is current low
         if(low[i]==extremum)
            ExtLowBuffer[i]=extremum;
         else
            ExtLowBuffer[i]=0.0;
         //--- find highest high in depth of bars
         extremum=high[iHighest(NULL,0,MODE_HIGH,InpDepth,i)];
         //--- this highest has been found previously
         if(extremum==lasthigh)
            extremum=0.0;
         else 
           {
            //--- new last high
            lasthigh=extremum;
            //--- discard extremum if current high is too low
            if(extremum-high[i]>InpDeviation*Point)
               extremum=0.0;
            else
              {
               //--- clear previous extremums in backstep bars
               for(back=1; back<=InpBackstep; back++)
                 {
                  pos=i+back;
                  if(ExtHighBuffer[pos]!=0 && ExtHighBuffer[pos]<extremum)
                     ExtHighBuffer[pos]=0.0; 
                 } 
              }
           }
         //--- found extremum is current high
         if(high[i]==extremum)
            ExtHighBuffer[i]=extremum;
         else
            ExtHighBuffer[i]=0.0;
        }
   //--- final cutting 
      if(whatlookfor==0)
        {
         lastlow=0.0;
         lasthigh=0.0;  
        }
      else
        {
         lastlow=curlow;
         lasthigh=curhigh;
        }
      for(i=limit; i>=0; i--)
        {
         switch(whatlookfor)
           {
            case 0: // look for peak or lawn 
               if(lastlow==0.0 && lasthigh==0.0)
                 {
                  if(ExtHighBuffer[i]!=0.0)
                    {
                     lasthigh=High[i];
                     lasthighpos=i;
                     whatlookfor=-1;
                     ExtZigzagBuffer[i]=lasthigh;
                    }
                  if(ExtLowBuffer[i]!=0.0)
                    {
                     lastlow=Low[i];
                     lastlowpos=i;
                     whatlookfor=1;
                     ExtZigzagBuffer[i]=lastlow;
                    }
                 }
                break;  
            case 1: // look for peak
               if(ExtLowBuffer[i]!=0.0 && ExtLowBuffer[i]<lastlow && ExtHighBuffer[i]==0.0)
                 {
                  ExtZigzagBuffer[lastlowpos]=0.0;
                  lastlowpos=i;
                  lastlow=ExtLowBuffer[i];
                  ExtZigzagBuffer[i]=lastlow;
                 }
               if(ExtHighBuffer[i]!=0.0 && ExtLowBuffer[i]==0.0)
                 {
                  lasthigh=ExtHighBuffer[i];
                  lasthighpos=i;
                  ExtZigzagBuffer[i]=lasthigh;
                  whatlookfor=-1;
                 }   
               break;               
            case -1: // look for lawn
               if(ExtHighBuffer[i]!=0.0 && ExtHighBuffer[i]>lasthigh && ExtLowBuffer[i]==0.0)
                 {
                  ExtZigzagBuffer[lasthighpos]=0.0;
                  lasthighpos=i;
                  lasthigh=ExtHighBuffer[i];
                  ExtZigzagBuffer[i]=lasthigh;
                 }
               if(ExtLowBuffer[i]!=0.0 && ExtHighBuffer[i]==0.0)
                 {
                  lastlow=ExtLowBuffer[i];
                  lastlowpos=i;
                  ExtZigzagBuffer[i]=lastlow;
                  whatlookfor=1;
                 }   
               break;               
           }
        }
        
        ////////////////////////////////////////////////////////////
        //  データの準備。山と谷を取り出す。
        ////////////////////////////////////////////////////////////
        
        int v,w,x, hi=1, li=1;
        for (v = 1; v < bars; v++ ) {
         
           if ( ExtLowBuffer[v] != 0.0 ) {          
              if ( ( li==1 ) || ( li!=1 && ExtLowBuffer[v] < LowBuffer[li-1]) ) {
                 LowBuffer[li] = ExtLowBuffer[v];
                 LowIndexBuffer[li] = v;
                 li++;
              }
           }
           
           if ( ExtHighBuffer[v] != 0.0 ) {
              if ( ( hi==1 ) || ( hi!=1 && ExtHighBuffer[v] > HighBuffer[hi-1]) ) {
                 HighBuffer[hi] = ExtHighBuffer[v];
                 HighIndexBuffer[hi] = v;
                 hi++;
              }
           }
        }     
        
        /////////////////////////////////////////////////////////////
        /////////////////////////////////////////////////////////////
        //   ここからメイン処理。　ラインを引く。
        /////////////////////////////////////////////////////////////
        /////////////////////////////////////////////////////////////
        
        
        double price;
        int    supportCnt=0; // いくつのポイントがラインを支えているか。始点を除く
        string obj_name = "TrendLine-";
        string obj_name2 = "TrendLine_";                
        int    chart_id = 0;
        int    tlCnt=1;    // 初めにTLを作るときに使用したりするカウント（仮のカウント
        int    tlCnt2=1;   // TLの名前を変えるの時に使用する数のカウント
        int    check[10];  // 同じ支えのラインが2本以上生成されていないか確かめるよう。
        int    check2[10];
        double ma1, ma2;
        
        
        for ( x = 0; x < 10; x++ ) {
          check[x] = 0;
          check2[x]= 0;
        }
        
        /////////////////////////////////////////////////////////////
        // 山を後ろから見ていってレジスタンスラインを引く
        /////////////////////////////////////////////////////////////
        
        decideTimeF();
        
        ma1 = iMA(NULL, TimeF, MaFilter1, 0, MODE_SMA, PRICE_CLOSE, 1); // 最後の１は本来iの部分だけど今回は微妙だったからとりあえず１にした。
        ma2 = iMA(NULL, TimeF, MaFilter2, 0, MODE_SMA, PRICE_CLOSE, 1); // 最後の１は本来iの部分だけど今回は微妙だったからとりあえず１にした。
        
        if ( ma1 > ma2 ) {
        
           for ( v = hi-1; v > 2; v-- ){ // 後ろからなので最低でも前に2つ残しておかないと3点支えできないから。
              for ( w = v-1; w > 1; w-- ) { // 前に1つ残してそれもつながるか用           
                 if ( HighIndexBuffer[v] > minBars ) {
                      ObjectCreate(0,obj_name+tlCnt,                                      // オブジェクト作成
                                   OBJ_TREND,                                             // オブジェクトタイプ
                                   0,                                                     // サブウインドウ番号
                                   Time[HighIndexBuffer[v]],                              // 1番目の時間のアンカーポイント
                                   HighBuffer[v],                                         // 1番目の価格のアンカーポイント
                                   Time[HighIndexBuffer[w]],                              // 1番目の時間のアンカーポイント
                                   HighBuffer[w]                                          // 2番目の価格のアンカーポイント
                      );
                      
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_COLOR,Resistance); // ラインの色設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_STYLE,STYLE_SOLID);// ラインのスタイル設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_WIDTH,1);          // ラインの幅設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_BACK,false);       // オブジェクトの背景表示設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_SELECTABLE,true);  // オブジェクトの選択可否設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_SELECTED,false);   // オブジェクトの選択状態
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_HIDDEN,false);     // オブジェクトリスト表示設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_ZORDER,0);         // オブジェクトのチャートクリックイベント優先順位         
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_RAY_RIGHT,true);   // ラインの延長線(右)
         
         
                     ///////////////////////////////////////////////////////
                     // 　　トレンドラインを抜けている値動きがあればそのトレンドラインを消す。
                     ///////////////////////////////////////////////////////
                     
                      for ( x = HighIndexBuffer[v]-1; x > 0; x--) {             
                        price = ObjectGetValueByShift(obj_name+tlCnt, x);                          
                        if ( !(price + _Point*n_point >= High[x])) { 
                           ObjectDelete(chart_id, obj_name+tlCnt);
                        }
                      }
                     
                     
                     ///////////////////////////////////////////////////////
                     // 　　トレンドラインを支えているポイントのカウントと記憶
                     ///////////////////////////////////////////////////////
                     
                     check2[0] = tlCnt; // トレンドラインの番号を保存しておくことで＠で消しやすくする。
                     for ( x = v; x > 0; x--) {             
                        if ( HighIndexBuffer[x] > 3 ) { // 最新の足が山と判断されてラインが惹かれるのを防ぐため。
                           price = ObjectGetValueByShift(obj_name+tlCnt, HighIndexBuffer[x]);                            
                           // トレンドラインを支える山をカウントする。始点を除く。
                           if ( price + _Point*n_point >= HighBuffer[x] && price - _Point*n_point <= HighBuffer[x]) {
                               supportCnt += 1;
                               check2[supportCnt] = HighIndexBuffer[x];
                           }
                        }
                     }
                                 
                     ///////////////////////////////////////////////////////
                     // 　　支えの数によって分岐処理
                     ///////////////////////////////////////////////////////
                                 
                     
                      if ( supportCnt < 3 ) { // 3点以上で支えていなければ.
                         ObjectDelete(chart_id, obj_name+tlCnt);
                      } else if (check2[1]-check2[2] < distBars || check2[2] - check2[3] < distBars ) { // 各支えの間が最低でもdistBars分離れていないと消す
                         ObjectDelete(chart_id, obj_name+tlCnt);                   
                      } else if (check2[1]-check2[3] <= distBars2 ) { // 1点目の支えと3点目の支えが最低でもdistBars2分離れていないと消す
                         ObjectDelete(chart_id, obj_name+tlCnt);                   
                      } else {
                        // 3点以上支えてる場所が被っていたら生成したラインを削除する。    
                        int checkCnt=0;         
                        for ( x = 1; x < 10; x++ ) { //0はトレンドライン番号なので飛ばす。
                           if ( check[x] == check2[x] && check[x] != 0 ) {
                              checkCnt += 1;
                           }
                        }
                                                            
                        if (1) {   //  もし過去に同じところにラインを引いていたら今回のラインは消す。
                           int    obj_total=ObjectsTotal();
                           string name;   
                           double Oparam1, Oparam2, Oparam3, Oparam4;
                           
                           for ( x = 0; x < obj_total; x++) {         
                             name=ObjectName(x);
                             if ( StringFind(name, obj_name2, 0) != -1 ) {
                                Oparam1 = ObjectGetDouble(chart_id, obj_name+tlCnt, OBJPROP_PRICE, 0);
                                Oparam2 = ObjectGetDouble(chart_id, obj_name+tlCnt, OBJPROP_PRICE, 1);
                                Oparam3 = ObjectGetDouble(chart_id, name, OBJPROP_PRICE, 0);
                                Oparam4 = ObjectGetDouble(chart_id, name, OBJPROP_PRICE, 1);
                                
                                if ( Oparam1 == Oparam3 && Oparam2 == Oparam4 ) {
                                  ObjectDelete(chart_id, obj_name+tlCnt);   
                                }
                             }
                           }
                        }
                        else if ( checkCnt >= 2 ) {
                           ObjectDelete(chart_id, obj_name+tlCnt);
                        } else {
                           for ( x = 0; x < 10; x++ ) {
                              check[x] = check2[x];
                              check2[x] = 0;
                           }
                        }  
                      }
                      
                  ///////////////////
                  //  更新
                  ///////////////////
                  
                      supportCnt = 0;
                      tlCnt++;
                 }
              }
           }
       }       
       
       for ( x = 0; x < 10; x++ ) {
         check[x] = 0;
         check2[x]= 0;
       }
       
       /////////////////////////////////////////////////////////////////////////////////////////////// 
       // 谷を後ろから見ていってサポートラインを引く。
       ///////////////////////////////////////////////////////////////////////////////////////////////
        
        decideTimeF();
        
        ma1 = iMA(NULL, TimeF, MaFilter1, 0, MODE_SMA, PRICE_CLOSE, 1); // 最後の１は本来iの部分だけど今回は微妙だったからとりあえず１にした。
        ma2 = iMA(NULL, TimeF, MaFilter2, 0, MODE_SMA, PRICE_CLOSE, 1); // 最後の１は本来iの部分だけど今回は微妙だったからとりあえず１にした。
        
        if ( ma1 < ma2 ) {
        
           for ( v = li-1; v > 2; v-- ){ // 後ろからなので最低でも前に2つ残しておかないと3点支えできないから。
              for ( w = v-1; w > 1; w-- ) { // 前に1つ残しす。それもつながるか試すため                            
                 if ( LowIndexBuffer[v] > minBars ) { // 最低でも始点から最新のバーまでminBars分は離れていないとラインを引かない。
                      ObjectCreate(0,obj_name+tlCnt,                                       // オブジェクト作成
                                   OBJ_TREND,                                              // オブジェクトタイプ
                                   0,                                                      // サブウインドウ番号
                                   Time[LowIndexBuffer[v]],                                // 1番目の時間のアンカーポイント
                                   LowBuffer[v],                                           // 1番目の価格のアンカーポイント
                                   Time[LowIndexBuffer[w]],                                // 1番目の時間のアンカーポイント
                                   LowBuffer[w]                                            // 2番目の価格のアンカーポイント
                      );
                      
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_COLOR,Resistance);  // ラインの色設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_STYLE,STYLE_SOLID); // ラインのスタイル設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_WIDTH,1);           // ラインの幅設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_BACK,false);        // オブジェクトの背景表示設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_SELECTABLE,true);   // オブジェクトの選択可否設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_SELECTED,false);    // オブジェクトの選択状態
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_HIDDEN,false);      // オブジェクトリスト表示設定
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_ZORDER,0);          // オブジェクトのチャートクリックイベント優先順位         
                      ObjectSetInteger(chart_id,obj_name+tlCnt,OBJPROP_RAY_RIGHT,true);    // ラインの延長線(右)
                      
                      
                      
                     ///////////////////////////////////////////////////////
                     // 　　トレンドラインを抜けている値動きがあればそのトレンドラインを消す。
                     ///////////////////////////////////////////////////////
                     
                      for ( x = LowIndexBuffer[v]-1; x > 0; x--) {             
                        price = ObjectGetValueByShift(obj_name+tlCnt, x);
                        if ( !(price - _Point*n_point <= Low[x])) {
                           ObjectDelete(chart_id, obj_name+tlCnt);           
                        }             
                      }
                     
                     
                     ///////////////////////////////////////////////////////
                     // 　　トレンドラインを支えているポイントのカウントと記憶
                     ///////////////////////////////////////////////////////
                     
                     check2[0] = tlCnt; // トレンドラインの番号を保存しておくことで＠で消しやすくする。
                     for ( x = v-1; x > 0; x--) {                         
                        if ( LowIndexBuffer[x] > 3 ) { // 最新の足が山と判断されてラインが惹かれるのを防ぐため。
                           price = ObjectGetValueByShift(obj_name+tlCnt, LowIndexBuffer[x]);                            
                           // トレンドラインを支える山をカウントする。始点を除く。
                           if ( price + _Point*n_point >= LowBuffer[x] && price - _Point*n_point <= LowBuffer[x]) {
                               supportCnt += 1;
                               check2[supportCnt] = LowIndexBuffer[x];
                           }
                        }
                     }
                     
                     
                     ///////////////////////////////////////////////////////
                     // 　　支えの数によって分岐処理
                     ///////////////////////////////////////////////////////                                                              
                     
                      if ( supportCnt < 3 ) { // 3点以上で支えていなければ.
                         ObjectDelete(chart_id, obj_name+tlCnt);
                      }else if (check2[1]-check2[2] < distBars || check2[2] - check2[3] < distBars ) {
                         ObjectDelete(chart_id, obj_name+tlCnt);                   
                      }else if (check2[1]-check2[3] <= distBars2 ) { // 1点目の支えと3点目の支えが最低でもdistBars2分離れていないと消す
                         ObjectDelete(chart_id, obj_name+tlCnt);                   
                      } else {
                        // 3点以上支えてる場所が被っていたら生成したラインを削除する。    
                        int checkCnt=0;         
                        for ( x = 1; x < 10; x++ ) { //0はトレンドライン番号なので飛ばす。
                           if ( check[x] == check2[x] && check[x] != 0 ) {
                              checkCnt += 1;
                           }
                        }
                        if (1) {   //  もし過去に同じところにラインを引いていたら今回のラインは消す。                     
                           int    obj_total=ObjectsTotal();
                           string name;   
                           double Oparam1, Oparam2, Oparam3, Oparam4;
                           
                           for ( x = 0; x < obj_total; x++) {         
                             name=ObjectName(x);
                             if ( StringFind(name, obj_name2, 0) != -1 ) {
                                Oparam1 = ObjectGetDouble(chart_id, obj_name+tlCnt, OBJPROP_PRICE, 0);
                                Oparam2 = ObjectGetDouble(chart_id, obj_name+tlCnt, OBJPROP_PRICE, 1);
                                Oparam3 = ObjectGetDouble(chart_id, name, OBJPROP_PRICE, 0);
                                Oparam4 = ObjectGetDouble(chart_id, name, OBJPROP_PRICE, 1);                                                        
                    
                                if ( Oparam1 == Oparam3 && Oparam2 == Oparam4 ) {
                                   ObjectDelete(chart_id, obj_name+tlCnt);   
                                } 
                             }
                           }
                        }
                        else if ( checkCnt >= 2 ) {  // 支えてるポイントが被ってる場合は消す。
                           ObjectDelete(chart_id, obj_name+tlCnt);
                        } else {
                           for ( x = 0; x < 10; x++ ) {
                              check[x] = check2[x];
                              check2[x] = 0;
                           }
                        }  
                      }
                      
                      supportCnt = 0;
                      tlCnt++;
         
                 }
              }
           } 
       }         
        
      //////////////////////////////////////////////////////////////////
      // 　　1ミリぐらいしか違わないTLを消す                                 　 //
      //////////////////////////////////////////////////////////////////        
        
      int    obj_total=ObjectsTotal();
      string name, name2;   
      double Oparam1, Oparam2, Oparam3, Oparam4;
      int y;
      int tmp1;
      int tmp2;
      
      for ( x = 0; x < obj_total; x++) {  
        name =ObjectName(x);   
        for ( y = 0; y < obj_total; y++) {  
                 
           if ( x == y ) continue;
           
           name2=ObjectName(y);
           if ( StringFind(name, obj_name, 0) != -1 ) {
           
              bool nameFlag1=false, nameFlag2=false;
              nameFlag1 = (StringFind(name2, obj_name,  0) != -1) ? true : false;
              nameFlag2 = (StringFind(name2, obj_name2, 0) != -1) ? true : false;
              
              if ( nameFlag1 || nameFlag2 ) {
                 Oparam1 = ObjectGetDouble(chart_id, name,  OBJPROP_PRICE, 0);
                 Oparam2 = ObjectGetDouble(chart_id, name2, OBJPROP_PRICE, 0);
                 
                 if ( Oparam1 == Oparam2 ) {
                    // 2点目の支えが同じかつ2点目からバーminBars2本(もしくわ最新バー)の位置でラインが互いにn_point2分離れていないなら消す => (ほとんど重なってるなら消す)
                    tmp1 = (ObjectGetShiftByValue(name, Oparam1)  - minBars2) > 1 ? ObjectGetShiftByValue(name, Oparam1)  - minBars2 : 1;
                    tmp2 = (ObjectGetShiftByValue(name2, Oparam2) - minBars2) > 1 ? ObjectGetShiftByValue(name2, Oparam2) - minBars2 : 1;
                    Oparam3 = ObjectGetValueByShift(name, tmp1);
                    Oparam4 = ObjectGetValueByShift(name2, tmp2);
                    
                    if ( MathAbs(Oparam3 - Oparam4) < _Point * n_point2 ) {
                      if ( nameFlag1 ) {
                         ObjectDelete(chart_id, name2);
                      } else {
                         ObjectDelete(chart_id, name ) ;
                      }
                    }
                 }
               }              
           } 
         } 
       }

        
        

      //////////////////////////////////////////////////////////////////
      // 　　トレンドラインの名前を変更して次回以降の処理で上書きされないようにする。　 //
      //////////////////////////////////////////////////////////////////
         
         obj_total=ObjectsTotal();
     //    string name;      
         string sep_str[];
         int    sep_num;
         int    tlNum=0;
         int    tlMaxNum=0;
         
         for ( v = 0; v < obj_total; v++) {         
           name=ObjectName(v);
           if ( StringFind(name, obj_name2, 0) != -1 ) {
              sep_num = StringSplit(name , '_' , sep_str);           
              tlNum = StrToInteger(sep_str[1]);
              if ( tlMaxNum < tlNum ) {
                 tlMaxNum = tlNum;
              }
           }                      
         }
         
         for ( v = 0; v < obj_total; v++) {         
           name=ObjectName(v);
           if ( StringFind(name, obj_name, 0) != -1 ) {
              printf(name);
              tlMaxNum += 1;
              printf(tlMaxNum);
              ObjectSetString(chart_id, name, OBJPROP_NAME, obj_name2 + tlMaxNum);   
              v -= 1; // オブジェクトが名前変更されたときそのオブジェクトが削除されて新たに追加された扱い？になるのかわからないがobjectNameでのindexが1つ詰められるために2番目のものがスルーされないようにインデックスをあえて戻すことによってすべてのobjを検索できるようにする。                      
           }                       
         }         
     }
                  
   //--- done
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int InitializeAll()
  {
   ArrayInitialize(ExtZigzagBuffer,0.0);
   ArrayInitialize(ExtHighBuffer,0.0);
   ArrayInitialize(ExtLowBuffer,0.0);
//--- first counting position
   return(bars-InpDepth);
  }
//+------------------------------------------------------------------+

bool isNewBar(string symbol, ENUM_TIMEFRAMES tf)
{
   static datetime time = 0;
   if(iTime(symbol, tf, 0) != time)
   {
      time = iTime(symbol, tf, 0);
      return true;
   }
   return false;
}

void DeleteTL() 
{
   int    obj_total=ObjectsTotal();
   string name;   
   string obj_name = "TrendLine_";
   int i;
   
   for ( i = 0; i < obj_total; i++) {         
     name=ObjectName(i);
     if ( StringFind(name, obj_name, 0) != -1 ) {
        ObjectDelete(0, name);
     }                      
   }
}

void decideTimeF()
{
   int timef = Period();
   
   switch(timef) {
      case 1:
         TimeF = 5;
         break;
      case 5:
         TimeF = 15;
         break;
      case 15:
         TimeF = 30;
         break;
      case 30:
         TimeF = 60;
         break;
      case 60:
         TimeF = 240;
         break;
      case 240:
         TimeF = 1440;
         break;
      default:
         TimeF = timef;
         break;
    }
}