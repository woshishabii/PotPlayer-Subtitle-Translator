string userAgent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36";
string appId = "";//appid
string toKen = "";//密钥
int NULL = 0;
int executeThreadId = NULL;//这个变量的命名是我的目标，不过，暂时没能实现!只是做了个还有小bug的临时替代方案
int nextExecuteTime = 0;//下次执行代码的时间

string GetVersion(){
    return "1";
}

string GetTitle(){
    return "HuggingFaceTranslation";
}

string GetDesc(){
    return "https://huggingface.co";
}

string GetLoginTitle(){
    return "输入配置";
}

string GetLoginDesc(){
    return "这里不需要填写";
}

string GetUserText(){
    return "App ID:";
}

string GetPasswordText(){
    return "秘钥：";
}

array<string> GetSrcLangs(){
    array<string> ret = GetLangTable();
    
    ret.insertAt(0, "");
    return ret;
}

array<string> GetDstLangs(){
    return GetLangTable();
}

string ServerLogin(string appIdStr, string toKenStr){
    if(appIdStr.empty() || toKenStr.empty()) return "fail";

    appId = appIdStr;
    toKen = toKenStr;
    return "200 ok";
}

string Translate(string text, string &in srcLang, string &in dstLang){
    string ret = "";
    if(!text.empty()){
        string q = HostUrlEncode(text);
        string url = "http://127.0.0.1:5000/translate/" + q;
        acquireExclusiveLock();
        string html = HostUrlGetString(url, userAgent);
        releaseExclusiveLock();
        if(!html.empty()){
            ret = JsonParse(html);
        }
        if(ret.empty()){
            ret = "    ";
        }

        if(ret.length() > 0){//如果有翻译结果
            srcLang = "UTF8";
            dstLang = "UTF8";
        }
    }
    return ret;
}

string GetLang(string &in lang){
    string result = lang;

    if(result.empty()){//空字符串
        result = "auto";
    } else if(result == "zh-CN"){//简体中文
        result = "zh";
    } else if(result == "zh-TW"){//繁体中文
        result = "cht";
    } else if(result == "ja"){//日语
        result = "jp";
    } else if(result == "ro"){//罗马尼亚语
        result = "rom";
    }

    return result;
}

array<string> langTable = {
    "zh-CN",//->zh
    "zh-TW",//->cht
    "en",
    "ja",//->jp
    "kor",
    "fra",
    "spa",
    "th",
    "ara",
    "ru",
    "pt",
    "de",
    "it",
    "el",
    "nl",
    "pl",
    "bul",
    "est",
    "dan",
    "fin",
    "cs",
    "ro",//->rom
    "slo",
    "swe",
    "hu",
    "vie",
    "yue",//粤语
    "wyw",//文言文
};

array<string>  GetLangTable(){
    return langTable;
}

string JsonParse(string json){
    string ret = "";//返回值
    JsonReader reader;
    JsonValue root;

    if (reader.parse(json, root)){//如果成功解析了json内容
        if(root.isObject()){//要求是对象模式
            array<string> keys = root.getKeys();//获取json root对象中所有的key
            JsonValue transResult = root["Result"];//取得翻译结果
            if(transResult.isArray()){//如果有翻译结果-必须是数组形式
                for(int i = 0; i < transResult.size(); i++){
                    JsonValue item = transResult[i];//取得翻译结果
                    JsonValue dst = item["dst"];//获取翻译结果的目标
                    if(i > 0){//如果需要处理多行的情况
                        ret += "\n";//第二行开始的开头位置，加上换行符
                    }
                    ret += dst.asString();//拼接翻译结果，可能存在多行
                }
            }
        }
    } 
    return ret;
}

void acquireExclusiveLock(){
    int tickCount1 = HostGetTickCount();//取得第一个时刻
    HostSleep(1);
    int tickCount2 = HostGetTickCount();//取得第二个时刻
    /**
    注意：
    1、这是一个临时的方案
    2、因为我本地尝试：HostLoadLibrary("Kernel32.dll") 没能正常工作，所以才采用当前这个临时方案
    3、key 原本应该是唯一的，不然可能存在多个线程得到的是同一个tickCount。会导致多个线程同时执行，意味着这多个线程只能成功一个翻译，虽然已经做了部分防御，但是不能确保万一！
    4、当然，上方的触发的概率不高，不过确实存在这个bug。
    5、所以当前只能作为临时方案，有更好的方案时，必须替换掉
    */
    int key = tickCount1 << 16 + (tickCount2 & 0xFFFF);//两个时刻合并，使得多线程重复相同数字的概率下降，但还是有可能重复，当前这个算法，仅仅能作为临时的解决方案而已！

    while(executeThreadId != key){
        if(executeThreadId == NULL){//如果没其他任务在执行了
            executeThreadId = key;//尝试注册当前任务为执行任务
        }

        HostSleep(1);//休息下，看看有没有抢着注册的其他线程任务，或者等待正在执行的任务解除锁

        if(executeThreadId == key){//如果没被其他线程抢注册了
            HostSleep(1);//再次休息下
            if(executeThreadId == key){//二次确认，确保原子性
                break;//成功抢到执行权限，不必再等待了
            }
        }
    }
}

void releaseExclusiveLock(){
    executeThreadId = NULL;//解除锁
}
