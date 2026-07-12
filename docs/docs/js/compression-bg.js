/**
 * Shrinkeo Background - Video Compression Metaphor
 * Draws floating video frames that shrink in size as they move across the screen.
 */

class CompressionBackground {
    constructor(canvasId) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.frames = [];
        this.frameCount = 40;
        this.accentColor = '#68B2C4'; // Lighter Teal for visibility

        this.init();
        this.animate();

        window.addEventListener('resize', () => this.resize());
    }

    init() {
        this.resize();
        this.frames = [];
        for (let i = 0; i < this.frameCount; i++) {
            this.frames.push(new VideoFrame(this.canvas.width, this.canvas.height));
        }
    }

    resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    draw() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        for (let i = 0; i < this.frames.length; i++) {
            this.frames[i].update(this.canvas.width);
            this.frames[i].draw(this.ctx, this.accentColor);
        }
    }

    animate() {
        this.draw();
        requestAnimationFrame(() => this.animate());
    }
}

class VideoFrame {
    constructor(width, height) {
        this.reset(width, height, true);
    }

    reset(width, height, randomX = false) {
        this.y = Math.random() * height;
        // Start from left side
        this.x = randomX ? (Math.random() * width) : -100;
        
        // Base size
        this.baseWidth = Math.random() * 60 + 40;
        this.baseHeight = this.baseWidth * 0.5625; // 16:9 ratio

        this.speed = Math.random() * 0.8 + 0.3;
        this.opacity = Math.random() * 0.15 + 0.05;
        this.lineWidth = Math.random() * 2 + 1;
    }

    update(canvasWidth) {
        this.x += this.speed;

        // Reset when it goes off screen
        if (this.x > canvasWidth + 100) {
            this.reset(canvasWidth, window.innerHeight);
        }
    }

    draw(ctx, color) {
        ctx.save();
        
        // Calculate compression factor based on X position
        // Starts at 1.0 (left), shrinks to 0.3 (right)
        const progress = Math.min(Math.max(this.x / window.innerWidth, 0), 1);
        const scale = 1.0 - (progress * 0.7); 
        
        const currentWidth = this.baseWidth * scale;
        const currentHeight = this.baseHeight * scale;

        // Increase opacity slightly as it compresses to show "density"
        const currentOpacity = this.opacity + (progress * 0.1);

        ctx.strokeStyle = color;
        ctx.globalAlpha = currentOpacity;
        ctx.lineWidth = this.lineWidth;

        // Draw video frame (rectangle)
        ctx.beginPath();
        ctx.rect(this.x, this.y, currentWidth, currentHeight);
        ctx.stroke();

        // Draw a tiny "play button" triangle inside if it's large enough
        if (currentWidth > 20) {
            ctx.beginPath();
            ctx.moveTo(this.x + currentWidth * 0.4, this.y + currentHeight * 0.3);
            ctx.lineTo(this.x + currentWidth * 0.4, this.y + currentHeight * 0.7);
            ctx.lineTo(this.x + currentWidth * 0.6, this.y + currentHeight * 0.5);
            ctx.closePath();
            ctx.stroke();
        }

        ctx.restore();
    }
}

window.onload = () => {
    new CompressionBackground('network-canvas');
};
