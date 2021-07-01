async function delay(max_ms) {
    const ms = Math.floor(Math.random() * max_ms)
    await new Promise(resolve => setTimeout(resolve, ms))
}

module.exports = delay
