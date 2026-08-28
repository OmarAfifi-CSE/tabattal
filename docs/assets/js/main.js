document.addEventListener('DOMContentLoaded', () => {
    
    // 1. Navbar blurring effect on scroll
    const navbar = document.getElementById('navbar');
    const navContainer = document.getElementById('navbar-container');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.classList.add('bg-brand-dark/80', 'backdrop-blur-md');
            navContainer.classList.remove('py-4');
            navContainer.classList.add('py-2');
        } else {
            navbar.classList.remove('bg-brand-dark/80', 'backdrop-blur-md');
            navContainer.classList.remove('py-2');
            navContainer.classList.add('py-4');
        }
    });

    // Keep the landing page fully usable if either animation CDN is unavailable.
    if (typeof gsap === 'undefined' || typeof ScrollTrigger === 'undefined') {
        return;
    }
    gsap.registerPlugin(ScrollTrigger);
    // 2. ScrollTrigger for Features (Hero entrance is handled in Pure CSS to eliminate FOUC)
    gsap.fromTo('#features .section-title',
        { y: 50, opacity: 0 },
        {
            y: 0, opacity: 1, duration: 1,
            scrollTrigger: {
                trigger: '#features',
                start: 'top 80%',
            }
        }
    );

    // 4. Showcase Text and Visual
    gsap.fromTo('.showcase-text > *', 
        { y: 35, opacity: 0 },
        {
            y: 0, opacity: 1, duration: 0.8, stagger: 0.2,
            scrollTrigger: {
                trigger: '#mushaf',
                start: 'top 70%',
            }
        }
    );

    gsap.fromTo('.showcase-visual', 
        { scale: 0.9, opacity: 0 },
        {
            scale: 1, opacity: 1, duration: 1, ease: 'power2.out',
            scrollTrigger: {
                trigger: '#mushaf',
                start: 'top 60%',
            }
        }
    );

    // 5. Philosophy / Numbers counter
    gsap.fromTo('.philosophy-content', 
        { y: 50, opacity: 0 },
        {
            y: 0, opacity: 1, duration: 1,
            scrollTrigger: {
                trigger: '#philosophy',
                start: 'top 70%',
            }
        }
    );

    // 6. Detailed Features Grid
    gsap.utils.toArray('#features .feature-card').forEach((card, i) => {
        gsap.fromTo(card, 
            { y: 30, opacity: 0 },
            {
                y: 0, opacity: 1, duration: 0.8,
                delay: i % 3 * 0.1, // Stagger rows
                scrollTrigger: {
                    trigger: card,
                    start: 'top 85%',
                }
            }
        );
    });

    // 7. How It Works Steps
    gsap.fromTo('#how-it-works .step-card', 
        { y: 40, opacity: 0 },
        {
            y: 0, opacity: 1, duration: 0.8, stagger: 0.2,
            scrollTrigger: {
                trigger: '#how-it-works',
                start: 'top 75%',
            }
        }
    );

    // 8. Magnetic Button Effect
    const magneticButtons = document.querySelectorAll('.magnetic-btn');
    
    magneticButtons.forEach(btn => {
        btn.addEventListener('mousemove', (e) => {
            const rect = btn.getBoundingClientRect();
            const h = rect.width / 2;
            
            const x = e.clientX - rect.left - h;
            const y = e.clientY - rect.top - h;
            
            gsap.to(btn, {
                x: x * 0.1,
                y: y * 0.1,
                duration: 0.3,
                ease: 'power2.out'
            });
        });
        
        btn.addEventListener('mouseleave', () => {
            gsap.to(btn, {
                x: 0,
                y: 0,
                duration: 0.5,
                ease: 'elastic.out(1, 0.3)'
            });
        });
    });
});

