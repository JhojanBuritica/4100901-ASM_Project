// --- Ejemplo de parpadeo de LED LD2 en STM32F476RGTx -------------------------
    .section .text
    .syntax unified
    .thumb

    .global main
    .global init_leds
    .global init_systick
    .global SysTick_Handler

// --- Definiciones de registros para LD2 (Ver RM0351) -------------------------
    .equ RCC_BASE,       0x40021000         @ Base de RCC
    .equ RCC_AHB2ENR,    RCC_BASE + 0x4C    @ Enable GPIOA clock (AHB2ENR)
    .equ GPIOA_BASE,     0x48000000         @ Base de GPIOA
    .equ GPIOA_MODER,    GPIOA_BASE + 0x00  @ Mode register
    .equ GPIOA_ODR,      GPIOA_BASE + 0x14  @ Output data register
    .equ LD2_PIN,        5                  @ Pin del LED LD2

// --- Definiciones de registros para el boton -------------------------
    .equ GPIOC_BASE,     0x48000800         @ Base de GPIOC
    .equ GPIOC_MODER,    GPIOC_BASE + 0x00  @ Mode register
    .equ GPIOC_IDR,      GPIOC_BASE + 0x10  @ Input data register
    .equ BUTTON_PIN,     13                 @ Pin del botón (PC13)

// --- Definiciones de registros para SysTick (Ver PM0214) ---------------------
    .equ SYST_CSR,       0xE000E010         @ Control and status
    .equ SYST_RVR,       0xE000E014         @ Reload value register
    .equ SYST_CVR,       0xE000E018         @ Current value register
    .equ HSI_FREQ,       4000000            @ Reloj interno por defecto (4 MHz)


// --- Programa principal ------------------------------------------------------

// Utilizamos un contador de 3 segundos
    .data
contador_3s:
    .word 0

    .text

main:
    bl init_leds
    bl init_systick


loop:

    wfi
    b loop

// --- Inicialización de GPIOA PA5 para el LED LD2 y para GPIOC -----------------------------
init_leds:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 0) | (1 << 2)               @ Habilita reloj GPIOA y GPIOC
    str   r1, [r0]

    // Configuracion para el PA5 como salida

    movw  r0, #:lower16:GPIOA_MODER
    movt  r0, #:upper16:GPIOA_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (LD2_PIN * 2)) @ Limpia bits MODER5
    orr   r1, r1, #(0b01 << (LD2_PIN * 2)) @ PA5 como salida
    str   r1, [r0]

    // Configurar PC13 como entrada
    movw  r0, #:lower16:GPIOC_MODER
    movt  r0, #:upper16:GPIOC_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (BUTTON_PIN * 2)) @ Limpia bits MODER13 (entrada)
    str   r1, [r0]

    bx    lr

// --- Inicialización de Systick para 1 s --------------------------------------
init_systick:
    movw  r0, #:lower16:SYST_RVR
    movt  r0, #:upper16:SYST_RVR
    movw  r1, #:lower16:HSI_FREQ
    movt  r1, #:upper16:HSI_FREQ
    subs  r1, r1, #1                       @ reload = 4 000 000 - 1
    str   r1, [r0]

    movw  r0, #:lower16:SYST_CSR
    movt  r0, #:upper16:SYST_CSR
    movs  r1, #(1 << 0)|(1 << 1)|(1 << 2)  @ ENABLE=1, TICKINT=1, CLKSOURCE=1
    str   r1, [r0]
    bx    lr

// --- Manejador de la interrupción SysTick ------------------------------------
    .thumb_func                            @ Ensure Thumb bit
SysTick_Handler:
    push {r4, r5}            @ Guardar registros temporales

    // Leer el estado de PC13
    movw  r0, #:lower16:GPIOC_IDR
    movt  r0, #:upper16:GPIOC_IDR
    ldr   r1, [r0]
    lsr   r1, r1, #BUTTON_PIN
    ands  r1, r1, #1

    // Si botón presionado (PC13 == 0)
    cmp   r1, #0
    bne   check_timer        @ Si no está presionado, ir a check_timer

    // Botón presionado: Encender LED y setear contador a 3
    movw  r2, #:lower16:contador_3s
    movt  r2, #:upper16:contador_3s
    movs  r3, #3
    str   r3, [r2]

    movw  r4, #:lower16:GPIOA_ODR
    movt  r4, #:upper16:GPIOA_ODR
    ldr   r5, [r4]
    orr   r5, r5, #(1 << LD2_PIN)
    str   r5, [r4]

check_timer:
    // Decrementar contador si es >0
    movw  r2, #:lower16:contador_3s
    movt  r2, #:upper16:contador_3s
    ldr   r3, [r2]
    cmp   r3, #0
    beq   end_handler         @ Si contador == 0, terminar
    subs  r3, r3, #1
    str   r3, [r2]

    // Si después de decrementar llega a 0, apagar el LED
    cmp   r3, #0
    bne   end_handler

    movw  r4, #:lower16:GPIOA_ODR
    movt  r4, #:upper16:GPIOA_ODR
    ldr   r5, [r4]
    bic   r5, r5, #(1 << LD2_PIN)
    str   r5, [r4]

end_handler:
    pop {r4, r5}              @ Restaurar registros
    bx    lr

