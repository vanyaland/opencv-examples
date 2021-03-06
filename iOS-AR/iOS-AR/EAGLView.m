/**
 * Copyright (c) 2017 Ivan Magda
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <QuartzCore/QuartzCore.h>

#import "EAGLView.h"

@interface EAGLView (PrivateMethods)
- (void)createFramebuffer;
- (void)deleteFramebuffer;
@end

@implementation EAGLView

// You must implement this method
+ (Class)layerClass {
  return [CAEAGLLayer class];
}

//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
- (id)initWithCoder:(NSCoder *)coder {
  if (self = [super initWithCoder:coder]) {
    CAEAGLLayer * eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO,
                                     kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    
    [self initContext];
  }
  
  return self;
}

- (void)dealloc {
  [self deleteFramebuffer];
  
  if ([EAGLContext currentContext] == self.context)
    [EAGLContext setCurrentContext:nil];
}

- (void)setContext:(EAGLContext *)newContext {
  if (self.context != newContext) {
    [self deleteFramebuffer];
    
    _context = newContext;
    
    [EAGLContext setCurrentContext:nil];
  }
}

- (void)createFramebuffer {
  if (self.context && !defaultFramebuffer) {
    [EAGLContext setCurrentContext: _context];
    
    // Create default framebuffer object.
    glGenFramebuffers(1, &defaultFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    
    // Create color render buffer and allocate backing store.
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_framebufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_framebufferHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
    
    // Create depth render buffer and allocate backing store.
    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _framebufferWidth, _framebufferHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
      NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
  }
}

- (void)deleteFramebuffer {
  if (self.context) {
    [EAGLContext setCurrentContext:_context];
    
    if (defaultFramebuffer) {
      glDeleteFramebuffers(1, &defaultFramebuffer);
      defaultFramebuffer = 0;
    }
    
    if (colorRenderbuffer) {
      glDeleteRenderbuffers(1, &colorRenderbuffer);
      colorRenderbuffer = 0;
    }
    
    if (depthRenderbuffer) {
      glDeleteRenderbuffers(1, &depthRenderbuffer);
      depthRenderbuffer = 0;
    }
    
    NSLog(@"Framebuffer deleted");
  }
}

- (void)setFramebuffer {
  if (self.context) {
    [EAGLContext setCurrentContext:_context];
    
    if (!defaultFramebuffer)
      [self createFramebuffer];
    
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glViewport(0, 0, _framebufferWidth, _framebufferHeight);
    
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
  }
}

- (BOOL)presentFramebuffer {
  BOOL success = FALSE;
  
  if (self.context) {
    [EAGLContext setCurrentContext:_context];
    
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    success = [self.context presentRenderbuffer:GL_RENDERBUFFER];
  }
  
  return success;
}

- (void)layoutSubviews {
  // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
  [self deleteFramebuffer];
}

- (void)initContext {
  EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
  
  if (!aContext)
    NSLog(@"Failed to create ES context");
  else if (![EAGLContext setCurrentContext:aContext])
    NSLog(@"Failed to set ES context current");
  
  [self setContext:aContext];
  [self setFramebuffer];
}

@end
