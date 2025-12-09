FROM golang:1.25.5 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o rivulet_server .

FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/rivulet_server .

RUN chmod +x rivulet_server

RUN mkdir -p assets

EXPOSE 8080

CMD ["./rivulet_server"]