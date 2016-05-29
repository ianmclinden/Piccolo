/*
Usage:
	This application is used to parse an input image, use various edge detection methods, and then draw it using the piccolo.
	
	Change the imgName variable to a .jpg image in the current directory (without the .jpg extension in the variable) that you want to draw.
	
	Set detect, thresh, or otsu to true depending on which method you want to use.

	This should take care of selecting the arduino port automatically, but make sure the proper system permissions exist.
	
Code could still use cleaning
*/

import piccoloP5.*;
  
import java.util.Map;
import processing.serial.*;

float[][] kernel = {{ -1, -1, -1}, 
                    { -1,  9, -1}, 
                    { -1, -1, -1}};
                    
PImage img;
float bedWidth = 50.0; 
float bedHeight = 50.0; 
float bedDepth = 50.0; 
float bedRenderWidth = 300;
boolean detect = false;
boolean thresh = false;
boolean otsu = false;
boolean debug = true;
String imgName = "JpegimageNameHere";

PiccoloP5 piccolo;
Serial serial;
void setup() { 
  size(400,400);
  if (!debug) {
   while(true) {
      try {
        piccolo = new PiccoloP5(bedWidth,bedHeight,bedDepth);
        piccolo.serial = new Serial(this, Serial.list()[0]); 
        piccolo.serialConnected = true;
      } catch(Exception e) {
        println("waiting for serial port");
        delay(1000);
      }
      if (piccolo.serial != null) {
        break;
      }
    }
  }
  //serial.write("C");
  img = loadImage(imgName + ".jpg"); // Load the original image
  img.resize(200, 200);
  noLoop();
  //Wait for the piccolo to be ready
 // while (!serial.readStringUntil('\n').contains("A")) {}
 if (!debug) {
   piccolo.start();
 }
}

/*
Image parsing techniques:
Edge detection
Grayscale
Threshold
*/


void draw() {
  println("beginning image parsing");
  image(img, 0, 0); // Displays the image from point (0,0) 
  img.loadPixels();
  // Create an image of the same size as the original
  PImage edgeImg = createImage(img.width, img.height, RGB);
  //if we're using edge detection
  if (detect) {
  // Loop through every pixel in the image.
  for (int y = 1; y < img.height-1; y++) { // Skip top and bottom edges
    for (int x = 1; x < img.width-1; x++) { // Skip left and right edges
      float redSum = 0, greenSum = 0, blueSum = 0; // Kernel sum for this pixel
      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          // Calculate the adjacent pixel for this kernel point
          int pos = (y + ky)*img.width + (x + kx);
          // Image is grayscale, red/green/blue are identical
          float redVal = red(img.pixels[pos]);
          float greenVal = green(img.pixels[pos]);
          float blueVal = blue(img.pixels[pos]);
          // Multiply adjacent pixels based on the kernel values
          redSum += kernel[ky+1][kx+1] * redVal;
          greenSum += kernel[ky+1][kx+1] * greenVal;
          blueSum += kernel[ky+1][kx+1] * blueVal;
        }
      }
      // For this pixel in the new image, set the gray value
      // based on the sum from the kernel
      edgeImg.pixels[y*img.width + x] = color(redSum, greenSum, blueSum);
    }
  }
    edgeImg.filter(GRAY);
	//if we're using thresholding
  } else if (thresh) {
    edgeImg = img;
    edgeImg.filter(GRAY);
    //edgeImg = toGray(edgeImg);
    //println(otsuTreshold(edgeImg));
    edgeImg.filter(THRESHOLD, otsuTreshold(edgeImg));
  } else if (otsu) {
    edgeImg = img;
    edgeImg.filter(GRAY);
  }
  image(edgeImg, width/2, 0); // Draw the new image
  
  edgeImg.updatePixels();
  img.updatePixels();
  
  color background = getDominantColor(edgeImg);
  int[][] lines = new int[img.height][img.width];
   for (int y = 1; y < img.height-1; y++) { 
    for (int x = 1; x < img.width-1; x++) { 
        color c = edgeImg.pixels[(y*img.width)+x];
        if (c != background) {
          lines[y][x] = 1;
        } else {
          lines[y][x] = 0;
        }
      }
   }  
  print2darray(lines);
   
   boolean liftedUp = false;
   //Last place drawn might not be the end of the line, so we want to lift z axis from the last drawn point
   int lastX = 0;
   float  zBase = -9;
   int imageSize = img.height;
   for (int y = 0; y < img.height-1; y++) { 
     if (y == round(img.height/2)) {
       zBase += 1;
     } else if (y == round(img.height/1.25)) {
       zBase += 1;
     }
    for (int x = 0; x < img.width-1; x++) { 
        if (lines[y][x] == 0 && !liftedUp) {
         // piccolo.stepTo(x-25, y-25, 0);
          stepTo(x, y, 10, img.height);
          liftedUp = true;
        } else if (lines[y][x] == 1) {
          if (liftedUp) {
            //piccolo.stepTo(x-25, y-25, 0);
            stepTo(x, y, 0, img.height);
          }
          //piccolo.stepTo(x-25, y-25, zBase);
          stepTo(x, y, zBase, imageSize);
          liftedUp = false;
          lastX = x;
        }
      }
      stepTo(lastX, y, 10, imageSize);
      liftedUp = true;
   } 
   
   //They don't make sure to clear the codestack, so we have to force every stepTo through
  /* for (int i = 0; i < (img.height+1)*(img.width-1); i++) {
     piccolo.update();
     delay(50);
   }*/
   
  
  // State that there are changes to edgeImg.pixels[]
  if (!debug) {
   while(true) {
     piccolo.update();
     delay(0);
   }
  }
   
   //Should do better denoising so we don't have to run multiple times
}

color getDominantColor(PImage image) {
  HashMap<Integer,Integer> hm = new HashMap<Integer,Integer>();
  for (int i = 0; i < image.pixels.length; i++) {
    int existing = 0;
    if (hm.containsKey(image.pixels[i])) {
     existing = hm.get(image.pixels[i]);
    }
     hm.put(image.pixels[i], ++existing); 
  }
  int max = 0;
  color maxColor = 0;
  for (Map.Entry me : hm.entrySet()) {
      if ((int)me.getValue() > max) {
         max = (int)me.getValue(); 
         maxColor = (color)me.getKey();
      }
  }
  
  return maxColor;
}

void stepTo(float x, float y, float z, int size) {
  
  //range is -25 to 25 on the piccolo
  float range = 50;
  float scale = size/range;
  if (size > range) {
    x = (x/scale)-(range/2);
    y = (y/scale)-(range/2);
  } else {
    x = x-(range/2);
    y = y-(range/2);
  }
  if (debug) {
   /* println("x: " + x + ", y: " + y + ", z: " + z);
    println("    scale: " + scale);
    println("    range: " + range);*/
  } else {
  piccolo.stepTo(x,y,z);
  piccolo.update();
  delay(0);
  }
}

void updatePosition(int x, int y, int z) {
  //Since it's a 50X50 matrix, and the piccolo starts indexing at -25
    x = x-25;
    y = y-25;
    z = z-25;
    int xScaled = (int) (x * 100.0);
    int yScaled = (int) (y * 100.0);
    int zScaled = (int) (z * 100.0);
    serial.write('P');
    sendInt(xScaled);
    sendInt(yScaled);
    sendInt(zScaled);
    serial.write(';');
}

void denoise(int[][] lines) {
  //trying to denoise
   for (int y = 1; y < img.height-2; y++) { 
    for (int x = 1; x < img.width-2; x++) { 
         if (lines[y][x] == 1 && lines[y][x+1] == 0) {
           lines[y][x] = 0; 
         }
      }
   }
}

void print2darray(int[][] lines) {
   for (int y = 0; y < img.height-1; y++) { 
    for (int x = 0; x < img.width-1; x++) { 
         print(lines[y][x]);
      }
      println();
   }
}


void sendInt(int i) {
    serial.write((byte) i | 0x00); // X
    serial.write((byte) (i >> 8) | 0x00); // X
    serial.write((byte) (i >> 16) | 0x00); // X
    serial.write((byte) (i >> 24) | 0x00); // X
}

int[] imageHistogram(PImage pimage) {
    int indexofpixel  = 0;
    int current_pixel = 0;
    int[] histogram = new int[256];
    pimage.loadPixels();
    for(int x = 0; x < pimage.width;x++) {
        for(int y = 0; y < pimage.height; y++) {       
            indexofpixel = x + y*pimage.width;
            current_pixel = pimage.pixels[indexofpixel];
            int red_value = (int) red(current_pixel);
            histogram[red_value]++;
        }
    }
    return histogram;
}  
  
  
 // Get binary treshold using Otsu's method
float otsuTreshold(PImage pimage) {
 
    int[] histogram = imageHistogram(pimage);
    int total = pimage.width * pimage.height;
 
    float sum = 0;
    for(int i = 0; i < 256; i++) {
        sum += i * histogram[i];
    }
 
    float sumB = 0;
    int wB = 0;
    int wF = 0;
 
    float varMax = 0;
    float threshold = 0.0;
 
    for(int i = 0 ; i < 256 ; i++) {
        wB += histogram[i];
        
        if(wB == 0) continue;
        wF = total - wB;
        if(wF == 0) break;
 
        sumB += i * histogram[i];
        float mB = sumB / wB;
        float mF = (sum - sumB) / wF;
 
        float varBetween = (float) wB * (float) wF * (mB - mF) * (mB - mF);
 
        if(varBetween > varMax) {
            varMax = varBetween;
            threshold = i;
        }
    }
    return (threshold/255);
}

PImage toGray(PImage pimage) {
 
      double red_value, green_value, blue_value;
      int current_pixel, grayscale, indexofpixel;
 
      PImage lum = new PImage(pimage.width,pimage.height,RGB);
 
      for(int x = 0; x< pimage.width; x++) {
          for(int y = 0; y < pimage.height; y++) {
              // Get pixels by R, G, B
              indexofpixel  = x + y*pimage.width; 
              current_pixel = pimage.pixels[indexofpixel];
              
              red_value   = red(current_pixel);
              green_value = green(current_pixel);
              blue_value  = blue(current_pixel);
 
              grayscale = (int) (0.2126 * red_value + 0.7152 * green_value + 0.0722 * blue_value); 
              // Write pixels into image
              lum.pixels[indexofpixel] = grayscale;
          }
      }
      lum.updatePixels();
      return lum;
    }
  