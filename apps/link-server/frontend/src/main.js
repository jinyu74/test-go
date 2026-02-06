import './style.css'
import { Greet } from '../wailsjs/go/main/App'

const app = document.querySelector('#app')

app.innerHTML = `
  <main class="container">
    <div class="card">
      <h1>Link Server</h1>
      <p class="subtitle">Go + Wails boilerplate</p>
      <div class="input-row">
        <input id="name" type="text" placeholder="Enter your name" autocomplete="off" />
        <button id="greet" type="button">Greet</button>
      </div>
      <div id="result" class="result">Waiting for input...</div>
    </div>
  </main>
`

const nameInput = document.querySelector('#name')
const result = document.querySelector('#result')
const greetButton = document.querySelector('#greet')

const runGreet = async () => {
  const name = nameInput.value
  result.textContent = 'Working...'

  try {
    const message = await Greet(name)
    result.textContent = message
  } catch (error) {
    console.error(error)
    result.textContent = 'Something went wrong. Check the dev console.'
  }
}

greetButton.addEventListener('click', runGreet)
nameInput.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    runGreet()
  }
})
