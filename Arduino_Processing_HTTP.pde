// Simple UI
// COM Port List, COM Port Choice
// Vehicle ID?
// Set Date Time?

//Interface
//Port change option
//Current Sensor threshold option - default. current current value.

import http.requests.*;

import processing.serial.*;
Serial myPort;
String values;
boolean firstContact = false;

int valuesCount = 3;                              // Number of values from Arduino
int[] receivedValues = new int[valuesCount];      // Array to store received values
int storeIndex = 0;

String delimitor = ",";
int sessionID = 0;

import http.requests.*;

String api = "http://SOMETHING";
String apiUser = "username";
String apiPass = "password";


void setup() {
  size(300, 300);
  background(0);

  printArray(Serial.list());
  myPort = new Serial(this, Serial.list()[0], 9600);
}

void draw() {
}

void serialEvent(Serial myPort) {

  if (!firstContact) {
    int inByte = myPort.read();
    if (inByte == 'A') {
      firstContact = true;
      myPort.clear();
      myPort.write('A');
    }
  } else {
    String data = myPort.readStringUntil('\n');

    if (data != null) {
      data = data.substring(0, data.length()-2);

      // ACCESS LOG REQUEST
      if (data.endsWith("$LOG")) {                     
        // IN (String _vehicle, String _user, String _date, String _time, boolean _start)
        // OUT "vehicle_id", "rfid_serial", "start_time"
        // RESPONSE "session_id"

        String dataArray[] = data.split(",");
        String login = dataArray[4].trim();

        String rfidSerial = dataArray[1];
        int vehicleID = int(dataArray[0]);

        // LOG IN REQUEST
        if (int(login) == 1) {                                   
          println("Login called");

          JSONObject json = new JSONObject();
          String apiEndpoint = "http://airtrack.eu-west-1.elasticbeanstalk.com/v1/createSession";

          json.setInt("vehicle_id", vehicleID);
          json.setString("rfid_serial", rfidSerial);
          json.setString("start_time", formatDateTime(dataArray[2], dataArray[3]));

          httpPost(json, apiEndpoint, true);
        } 

        // LOG OUT REQUEST
        else if (int(login) == 0) {            
          println("Logout called");

          JSONObject json = new JSONObject();
          String apiEndpoint = "http://airtrack.eu-west-1.elasticbeanstalk.com/v1/endSession";

          json.setInt("session_id", sessionID);
          json.setString("end_time", formatDateTime(dataArray[2], dataArray[3]));

          httpPost(json, apiEndpoint, false);

          sessionID = 0;
        } else println("Call Error");

        printArray(dataArray);
      } 



      // MALFUNCTION ERROR REQUEST
      else if (data.endsWith("$ERR")) {      
        // IN (String _vehicle, String _sessionID, String _date, String _time, Current lamp)
        // OUT "session_id", "time", "vehicle_id", "part_id"
        println("Error Request Called");

        String dataArray[] = data.split(",");

        printArray(dataArray);

        JSONObject json = new JSONObject();
        String apiEndpoint = "http://airtrack.eu-west-1.elasticbeanstalk.com/v1/createMalfunction";

        json.setInt("session_id", sessionID);
        json.setString("time", formatDateTime(dataArray[2], dataArray[3]));
        json.setInt("vehicle_id", int(dataArray[0]));
        json.setInt("part_id", int(dataArray[4]));

        httpPost(json, apiEndpoint, false);
      } 

      // MALFUNCTION FIX REQUEST
      else if (data.endsWith("$FIX")) {      
        // IN (String _vehicle, String _sessionID, String _date, String _time, Current lamp)
        // OUT "session_id", "time", "part_id"
        println("Fix Request Called");

        String dataArray[] = data.split(",");

        JSONObject json = new JSONObject();
        String apiEndpoint = "http://airtrack.eu-west-1.elasticbeanstalk.com/v1/fixMalfunction";

        //json.setInt("session_id", sessionID);
        json.setString("time", formatDateTime(dataArray[2], dataArray[3]));
        json.setInt("vehicle_id", int(dataArray[0]));                // ADD VEHICLE ID?
        json.setInt("part_id", int(dataArray[4]));

        httpPost(json, apiEndpoint, false);

        printArray(dataArray);
      } else println(data);
    }
  }
}


String formatDateTime(String _date, String _time) {
  println("FDT Called");
  println(_date);
  println(_time);
  String dateArray[] = _date.trim().split("\\.");
  printArray(dateArray);

  String day = dateArray[0].trim();
  String month = dateArray[1].trim();
  String year = dateArray[2].trim();

  String newDate = year + "-" + month + "-" + day + " " + _time + ".000000";
  println("New Date:");
  println(newDate);
  return newDate;
}


void httpPost(JSONObject json, String apiEndpoint, boolean logPost) {

  PostRequest post = new PostRequest(apiEndpoint);

  post.addHeader("Authorization", "Basic dGVzdDp0ZXN0");
  post.addHeader("Content-Type", "application/json");
  post.addJson(json.toString());

  post.send();

  System.out.println("Response Content: " + post.getContent());

  JSONObject response = parseJSONObject(post.getContent());
  if (logPost)  sessionID = response.getInt("session_id");
}