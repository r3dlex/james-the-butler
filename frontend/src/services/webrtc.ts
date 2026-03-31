export class WebRTCManager {
  private pc: RTCPeerConnection | null = null;
  private remoteStream: MediaStream | null = null;

  async connect(signalingSend: (msg: unknown) => void): Promise<MediaStream> {
    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });

    this.remoteStream = new MediaStream();

    this.pc.ontrack = (event) => {
      event.streams[0]?.getTracks().forEach((track) => {
        this.remoteStream!.addTrack(track);
      });
    };

    this.pc.onicecandidate = (event) => {
      if (event.candidate) {
        signalingSend({ type: "ice_candidate", candidate: event.candidate });
      }
    };

    return this.remoteStream;
  }

  async handleOffer(
    offer: RTCSessionDescriptionInit,
  ): Promise<RTCSessionDescriptionInit> {
    if (!this.pc) throw new Error("Not connected");
    await this.pc.setRemoteDescription(offer);
    const answer = await this.pc.createAnswer();
    await this.pc.setLocalDescription(answer);
    return answer;
  }

  async handleIceCandidate(candidate: RTCIceCandidateInit): Promise<void> {
    if (!this.pc) return;
    await this.pc.addIceCandidate(candidate);
  }

  disconnect(): void {
    this.pc?.close();
    this.pc = null;
    this.remoteStream = null;
  }
}
