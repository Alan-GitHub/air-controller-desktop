import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConnectionDisconnectedPage extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _ConnectionDisconnectionState();
  }

}

class _ConnectionDisconnectionState extends State<ConnectionDisconnectedPage> {

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Wrap(
          direction: Axis.horizontal,
          children: [
            Image.asset("icons/error_wrong.tiff", width: 540 * 0.6, height: 960 * 0.6),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Wrap(
                    direction: Axis.vertical,
                    children: [
                      Container(
                        child: Text(
                          "无线连接已断开",
                          style: TextStyle(
                              color: Color(0xff57595d),
                              fontSize: 23,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        margin: EdgeInsets.only(top: 150),
                      ),

                      Container(
                        child: Text(
                          "由于网络环境不稳定或手机端EasyHandler连接超时等原因，无线连接已断开，请检查。",
                          style: TextStyle(
                              color: Color(0xffdc0c0c0),
                              fontSize: 14
                          ),
                        ),
                        margin: EdgeInsets.only(top: 20),
                        width: 350,
                      )

                    ],
                  ),
                  Container(
                    child: OutlinedButton(
                      child: Text("返回主界面", style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff5b5c61)
                      )),
                      style: OutlinedButton.styleFrom(
                        fixedSize: Size(125, 40),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1.0, style: BorderStyle.solid),
                          borderRadius: BorderRadius.all(Radius.circular(5))
                        )
                      ),
                      onPressed: () {
                        _popToHomePage();
                      },
                    ),
                    // color: Colors.yellow,
                  )

                ],
              ),
              height: 960 * 0.6 - 50,
            )
          ],
        ),
      ),
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
    );
  }

  void _popToHomePage() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}