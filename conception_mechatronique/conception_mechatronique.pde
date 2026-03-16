import java.io.File;

float[] joints = {0, 0, 0, 0, 0, 0};
String[] names = {"J1: Base", "J2: Epaule", "J3: Coude", "J4: Poignet 1", "J5: Poignet 2", "J6: Poignet 3"};
int menus = 0;

void setup() {
  size(900, 600);
  surface.setResizable(true);
  textAlign(LEFT, CENTER);
  setupRobotBridge();
}

void draw() {
  background(25);
  updateRobotBridge();

  drawHeader();

  if (menus == 0) {
    draw_menus_1();
  } else if (menus == 1) {
    draw_menus_2();
  } else if (menus == 2) {
    draw_menus_3();
  }

  drawLiveTelemetryCard();
  drawFooter();
}

void drawHeader() {
  noStroke();
  fill(40);
  rect(0, 0, width, 60);

  drawTab(0, 0, width/3, 60, "MODELE GEOMETRIQUE DIRECT (MGD)", 0);
  drawTab(width/3, 0, width/3, 60, "MODELE GEOMETRIQUE INVERSE (MGI)", 1);
  drawTab(2*width/3, 0, width/3, 60, "CONTROL MANUELLE", 2);

  stroke(0, 120, 255);
  strokeWeight(2);
  line(0, 60, width, 60);
}

void drawTab(float x, float y, float w, float h, String label, int id) {
  boolean isSelected = (menus == id);
  boolean isHover = (mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h);

  if (isSelected) {
    fill(60);
  } else if (isHover) {
    fill(50);
    cursor(HAND);
  } else {
    fill(40);
    cursor(ARROW);
  }

  rect(x, y, w, h);

  textAlign(CENTER, CENTER);
  textSize(14);
  if (isSelected) {
    fill(0, 255, 150);
    rect(x + 20, y + h - 5, w - 40, 3);
  } else {
    fill(200);
  }
  text(label, x + w/2, y + h/2);

  if (isHover && mousePressed) {
    menus = id;
  }

  textAlign(LEFT, CENTER);
}

void drawFooter() {
  fill(40);
  noStroke();
  rect(0, height - 40, width, 40);

  fill(150);
  textSize(12);
  text(buildFooterStatus(), 20, height - 20);
}
