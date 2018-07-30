import processing.serial.*;
import processing.video.*;

Movie idle;
Movie intro;
Movie outro;
Movie question;
Movie current;

String[] filenames;

final int IDLE = 0;
final int PLAYING = 1;
final int TIMEOUT = 2;

int state = IDLE;
int questionLoop = 1;

Serial myPort;  // Create object from Serial class
float val;     // Data received from the serial port

import controlP5.*;

ControlP5 cp5;
DropdownList serialPortsList;
Slider sensorScale;

String[] config;

boolean debug = true;
float limit = 0.6;


void setup() {
  size(1280, 720);
  //size(640, 360);
  loadVideos();

  String path = sketchPath() + "/data/03_PREGUNTAS";
  filenames = listFileNames(path);
  printArray(filenames);

  loadSettings();
  noCursor();
}


void draw() {
  serialPortsList.setVisible(debug);
  sensorScale.setVisible(debug);
  
  if (parseSensor()) {
    if (state == IDLE) {
      state = PLAYING;
      loadNewQuestion();
      idle.stop();
      intro.play();
      current = intro;
    }
  }

  image(current, 0, 0, width, height);

  if (debug) {
    debugScreen();
  }
}

boolean parseSensor() {
  return val > limit;
}


void keyPressed() {
  if (key == ' ') {
    debug = !debug;
  }
}


void loadNewQuestion() { 
  questionLoop = 1;
  String questionFile = filenames[(int)random(filenames.length)];
  println("Loading: "+questionFile);

  question = new Movie(this, "03_PREGUNTAS/"+questionFile) { // cargo la pregunta...
    @ Override public void eosEvent() {
      super.eosEvent();
      questionEnd();
    }
  };
}

void movieEvent(Movie m) {
  m.read();
}


void introEnd() {
  println("intro end");
  question.play();
  current = question;
}



void questionEnd() {
  if (questionLoop == 0) {
    outro.play();
    current = outro;
  } else {
    questionLoop--;
    question.jump(0);
    question.play();
  }
}

void outroEnd() {
  println("outro end");
  resetVideos();
  idle.play();
  current = idle;
  state = TIMEOUT;
}


void idleEnd(){
  if(state == TIMEOUT) state = IDLE; // espero que termine una vez el video para dar tiempo a que salga la persona
}


void resetVideos() {
  intro.jump(0);
  intro.stop();
  outro.jump(0);
  outro.stop();

  idle.jump(0);
  idle.stop();
}
// This function returns all the files in a directory as an array of Strings  
String[] listFileNames(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } else {
    // If it's not a directory
    return null;
  }
}

// This function returns all the files in a directory as an array of File objects
// This is useful if you want more info about the file
File[] listFiles(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    return files;
  } else {
    // If it's not a directory
    return null;
  }
}

// Function to get a list of all files in a directory and all subdirectories
ArrayList<File> listFilesRecursive(String dir) {
  ArrayList<File> fileList = new ArrayList<File>(); 
  recurseDir(fileList, dir);
  return fileList;
}

// Recursive function to traverse subdirectories
void recurseDir(ArrayList<File> a, String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    // If you want to include directories in the list
    a.add(file);  
    File[] subfiles = file.listFiles();
    for (int i = 0; i < subfiles.length; i++) {
      // Call this function on all files in this directory
      recurseDir(a, subfiles[i].getAbsolutePath());
    }
  } else {
    a.add(file);
  }
}


void serialEvent(Serial myPort) {
  // read a byte from the serial port:
  String data = myPort.readStringUntil('\n');
  if (data != null && data != " "  && data.length() > 2) {
    val = float(trim(data));
    val = map(val, 0, sensorScale.getValue()/100.0, 0.0, 1.0);
    //println(val);
  }
}

void controlEvent(ControlEvent theEvent) {
  //String list[] = new String[2]; 

  if (theEvent.getController().getId() == 0) {    
    //check if there's a serial port open already, if so, close it
    if (myPort != null) {
      myPort.stop();
      myPort = null;
    }
    //open the selected core
    String portName = serialPortsList.getItem((int)theEvent.getValue()).get("name").toString();
    try {
      println("Starting serial: "+portName);
      myPort = new Serial(this, portName, 9600);
      config[0] = portName;
    }
    catch(Exception e) {
      System.err.println("Error opening serial port " + portName);
      e.printStackTrace();
    }
  }

  if (theEvent.getController().getId() == 1) {
    config[1] = ""+theEvent.getController().getValue();
  }

  saveStrings("settings.txt", config);
}


void loadVideos() {
  idle = new Movie(this, "01_ESPERA_v03.mp4"){
    @ Override public void eosEvent() {
      super.eosEvent();
      idleEnd();
    }
  };
  idle.loop();
  

  intro = new Movie(this, "02_INICIO_v06.mp4") {
    @ Override public void eosEvent() {
      super.eosEvent();
      introEnd();
    }
  };

  outro = new Movie(this, "04_SALE_v04.mp4") {
    @ Override public void eosEvent() {
      super.eosEvent();
      outroEnd();
    }
  };

  current = idle;
}

void loadSettings() {
  String[] portNames = Serial.list();

  cp5 = new ControlP5(this);
  serialPortsList = cp5.addDropdownList("puerto").setPosition(10, 10).setWidth(200).setId(0);
  for (int i = 0; i < portNames.length; i++) serialPortsList.addItem(portNames[i], i);  

  config = loadStrings("settings.txt");
  String lastPort = config[0];

  for (String port : portNames) {
    if (lastPort.equals(port)) {
      myPort = new Serial(this, port, 9600);
      debug = false;
    }
  }

  float sensorSetting = config[1] != null ? float(config[1]) : 50.0; 
  sensorScale =  cp5.addSlider("sensor")
    .setRange(0, 100)
    .setValue(sensorSetting)
    .setPosition(200, 250)
    .setSize(30, 100)
    .setColorValue(0xffff88ff)
    .setColorLabel(0xffdddddd)
    .setId(1)
    .setVisible(debug);
}

void debugScreen() {
  background(0);
  rectMode(CENTER);
  float dim = 300;
  rect(width/2, height/2, dim, dim);
  if (parseSensor()) {
    pushStyle();
    rectMode(CORNER);
    fill(255, 0, 0);
    rect(width/2 - dim/2, height/2 - dim/2, dim, dim * (1 - limit));
    popStyle();
  }
  float limitLine = (height/2 - dim/2) + (1 - limit) * dim;
  line(width/2 - dim/2, limitLine, width/2 + dim/2, limitLine); 
  float people = (height/2 + dim/2) - val *dim;
  ellipse(width/2, people, 80, 20);
}
