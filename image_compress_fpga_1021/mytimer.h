#ifndef _MYTIMER_H
#define _MYTIMER_H

#include <QObject>
class QTimer;
class MyTimer : public QObject
{
    Q_OBJECT

public:
    MyTimer(QObject* parent = NULL);
    ~MyTimer();
public slots:
    void handleTimeout();  //超时处理函数
private:
    QTimer *m_pTimer;
};

#endif //_MYTIMER_H
