#include "mytimer.h"

#include <QDebug>
#include <QTimer>

#define TIMER_TIMEOUT	(5*1000)

MyTimer::MyTimer(QObject *parent)
    :QObject(parent)
{
    m_pTimer = new QTimer(this);
    connect(m_pTimer, SIGNAL(timeout()), this, SLOT(handleTimeout()));
    m_pTimer->start(TIMER_TIMEOUT);
}

MyTimer::~MyTimer()
{

}

void MyTimer::handleTimeout()
{
    qDebug()<<"Enter timeout processing function\n";
    if(m_pTimer->isActive()){
        m_pTimer->stop();
    }
}
