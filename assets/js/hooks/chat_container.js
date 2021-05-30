export default {
  mounted(){
    this.handleEvent("chat_notify", ({message}) => console.log("Message from server", message));
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight;
  }
}