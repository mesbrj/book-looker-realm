FROM golang:alpine3.22 AS builder

WORKDIR /app
COPY . .
RUN go mod tidy
RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -o consumer main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/consumer .

CMD ["./consumer"]